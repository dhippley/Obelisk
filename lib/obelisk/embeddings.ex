defmodule Obelisk.Embeddings do
  @moduledoc """
  Embedding generation for text using various providers.

  Currently supports OpenAI's text-embedding-3-small model.

  Provides both synchronous embedding generation and asynchronous processing
  through the Broadway pipeline for improved efficiency and rate limiting.
  """

  alias Obelisk.Embeddings.Queue
  alias Req

  @openai_base_url "https://api.openai.com/v1"
  @default_model "text-embedding-3-small"
  @embedding_dimensions 1536

  @doc """
  Generate embeddings for the given text.

  ## Parameters
  - `text`: The text to embed
  - `opts`: Options map that may include `model`, `provider`, etc.

  ## Returns
  - `{:ok, embedding_vector}` on success
  - `{:error, reason}` on failure
  """
  def embed_text(text, opts \\ %{}) when is_binary(text) do
    provider = Map.get(opts, :provider, "openai")

    case provider do
      "openai" -> embed_text_openai(text, opts)
      _ -> {:error, {:unsupported_provider, provider}}
    end
  end

  @doc """
  Generate embeddings asynchronously through the Broadway pipeline.

  This is more efficient for multiple embeddings as it batches API calls.

  ## Parameters
  - `text`: The text to embed
  - `timeout`: Optional timeout in milliseconds (default: 30 seconds)

  ## Returns
  - `{:ok, embedding_vector}` on success
  - `{:error, reason}` on failure
  """
  def embed_text_async(text, timeout \\ 30_000) when is_binary(text) do
    Queue.embed_sync(text, timeout)
  end

  @doc """
  Generate embeddings asynchronously without blocking.

  Returns immediately with a reference. The caller will receive:
  `{:embedding_result, ref, {:ok, embedding} | {:error, reason}}`
  """
  def embed_text_async_nowait(text) when is_binary(text) do
    Queue.embed_async(text)
  end

  @doc """
  Get the dimensions of embeddings for the configured model.
  """
  def embedding_dimensions(opts \\ %{}) do
    model = Map.get(opts, :model, @default_model)

    case model do
      "text-embedding-3-small" -> @embedding_dimensions
      "text-embedding-3-large" -> 3072
      "text-embedding-ada-002" -> @embedding_dimensions
      # fallback
      _ -> @embedding_dimensions
    end
  end

  @doc """
  Get queue status and processing information.
  """
  def queue_info do
    Queue.queue_info()
  end

  # Private functions

  defp embed_text_openai(text, opts) do
    model = Map.get(opts, :model, @default_model)

    body = %{
      model: model,
      input: text,
      encoding_format: "float"
    }

    case Req.post(url: "#{@openai_base_url}/embeddings", headers: auth_headers(), json: body) do
      {:ok, %{status: 200, body: %{"data" => [%{"embedding" => embedding} | _]}}} ->
        {:ok, embedding}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp auth_headers do
    api_key = System.fetch_env!("OPENAI_API_KEY")
    [{"authorization", "Bearer #{api_key}"}]
  rescue
    _error in ArgumentError ->
      reraise RuntimeError,
              """
              OPENAI_API_KEY environment variable is required but not set.
              Please set your OpenAI API key:

                export OPENAI_API_KEY=sk-...
              """,
              __STACKTRACE__
  end
end
