defmodule Obelisk.LLM.Ollama do
  @moduledoc """
  Ollama LLM provider implementation for local language models.

  Requires Ollama to be running locally or set OLLAMA_BASE_URL environment variable.
  """

  @behaviour Obelisk.LLM
  alias Req

  @default_base_url "http://localhost:11434"
  @default_model "llama3.2"
  @default_temperature 0.2

  @doc """
  Send a chat completion request to Ollama.
  """
  def chat(messages, opts \\ %{}) do
    body = build_request_body(messages, opts)
    base_url = System.get_env("OLLAMA_BASE_URL", @default_base_url)

    case Req.post(url: "#{base_url}/api/chat", json: body) do
      {:ok, %{status: 200, body: response}} ->
        # Transform Ollama response to match OpenAI format
        transformed = transform_response(response)
        {:ok, transformed}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, %{reason: :econnrefused}} ->
        {:error,
         {:connection_failed,
          "Ollama server not running. Please start Ollama or check OLLAMA_BASE_URL"}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Send a streaming chat completion request to Ollama.

  Currently returns an error as streaming is not yet implemented.
  """
  def stream_chat(_messages, _opts, _callback) do
    {:error, :not_implemented}
  end

  # Private functions

  defp build_request_body(messages, opts) do
    model = Map.get(opts, :model) || System.get_env("OLLAMA_MODEL", @default_model)

    # Convert messages to Ollama format
    ollama_messages =
      messages
      |> Enum.map(fn msg ->
        role = msg.role || msg[:role]
        content = msg.content || msg[:content]

        %{
          role: convert_role(role),
          content: content
        }
      end)

    body = %{
      model: model,
      messages: ollama_messages,
      stream: false
    }

    # Add temperature if specified
    options = %{}

    options =
      case Map.get(opts, :temperature) do
        nil -> options
        temp -> Map.put(options, :temperature, temp || @default_temperature)
      end

    if map_size(options) > 0 do
      Map.put(body, :options, options)
    else
      body
    end
  end

  defp convert_role("user"), do: "user"
  defp convert_role("assistant"), do: "assistant"
  defp convert_role("system"), do: "system"
  defp convert_role(role) when is_atom(role), do: convert_role(to_string(role))
  defp convert_role(role), do: role

  defp transform_response(%{"message" => %{"content" => content}} = response) do
    # Transform Ollama response to OpenAI-compatible format
    %{
      "choices" => [
        %{
          "message" => %{
            "role" => "assistant",
            "content" => content
          },
          "finish_reason" => if(response["done"], do: "stop", else: "length")
        }
      ],
      "usage" => %{
        "prompt_tokens" => response["prompt_eval_count"] || 0,
        "completion_tokens" => response["eval_count"] || 0,
        "total_tokens" => (response["prompt_eval_count"] || 0) + (response["eval_count"] || 0)
      },
      "model" => response["model"] || @default_model
    }
  end

  defp transform_response(response) do
    # Fallback for unexpected response format
    %{
      "choices" => [
        %{
          "message" => %{
            "role" => "assistant",
            "content" => inspect(response)
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 0,
        "completion_tokens" => 0,
        "total_tokens" => 0
      },
      "model" => @default_model
    }
  end
end
