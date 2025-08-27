defmodule Obelisk.LLM.OpenAI do
  @moduledoc """
  OpenAI LLM provider implementation using the Chat Completions API.

  Requires OPENAI_API_KEY environment variable to be set.
  """

  @behaviour Obelisk.LLM
  alias Req

  @base_url "https://api.openai.com/v1"
  @default_model "gpt-4o-mini"
  @default_temperature 0.2

  @doc """
  Send a chat completion request to OpenAI.
  """
  def chat(messages, opts \\ %{}) do
    body = build_request_body(messages, opts)

    case Req.post(url: "#{@base_url}/chat/completions", headers: auth_headers(), json: body) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Send a streaming chat completion request to OpenAI.

  Currently returns an error as streaming is not yet implemented.
  """
  def stream_chat(_messages, _opts, _callback) do
    {:error, :not_implemented}
  end

  # Private functions

  defp build_request_body(messages, opts) do
    %{
      model: Map.get(opts, :model) || System.get_env("OPENAI_MODEL", @default_model),
      messages: messages,
      temperature: Map.get(opts, :temperature) || @default_temperature
    }
  end

  defp auth_headers do
    api_key = System.fetch_env!("OPENAI_API_KEY")
    [{"authorization", "Bearer #{api_key}"}]
  rescue
    _error in ArgumentError ->
      reraise RuntimeError, """
      OPENAI_API_KEY environment variable is required but not set.
      Please set your OpenAI API key:

        export OPENAI_API_KEY=sk-...
      """, __STACKTRACE__
  end
end
