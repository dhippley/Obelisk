defmodule Obelisk.LLM.Anthropic do
  @moduledoc """
  Anthropic (Claude) LLM provider implementation using the Messages API.

  Requires ANTHROPIC_API_KEY environment variable to be set.
  """

  @behaviour Obelisk.LLM
  alias Req

  @base_url "https://api.anthropic.com/v1"
  @default_model "claude-3-5-sonnet-20241022"
  @default_max_tokens 4000
  @default_temperature 0.2

  @doc """
  Send a chat completion request to Anthropic.
  """
  def chat(messages, opts \\ %{}) do
    body = build_request_body(messages, opts)

    case Req.post(url: "#{@base_url}/messages", headers: auth_headers(), json: body) do
      {:ok, %{status: 200, body: response}} ->
        # Transform Anthropic response format to match OpenAI format
        transformed = transform_response(response)
        {:ok, transformed}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Send a streaming chat completion request to Anthropic.

  Currently returns an error as streaming is not yet implemented.
  """
  def stream_chat(_messages, _opts, _callback) do
    {:error, :not_implemented}
  end

  # Private functions

  defp build_request_body(messages, opts) do
    # Convert from OpenAI-style messages to Anthropic format
    {system_prompt, user_messages} = extract_system_and_messages(messages)

    body = %{
      model: Map.get(opts, :model) || System.get_env("ANTHROPIC_MODEL", @default_model),
      max_tokens: Map.get(opts, :max_tokens) || @default_max_tokens,
      messages: user_messages
    }

    body =
      if system_prompt do
        Map.put(body, :system, system_prompt)
      else
        body
      end

    # Add temperature if specified
    case Map.get(opts, :temperature) do
      nil -> body
      temp -> Map.put(body, :temperature, temp || @default_temperature)
    end
  end

  defp extract_system_and_messages(messages) do
    # Find system messages and convert user/assistant messages
    {system_messages, other_messages} =
      Enum.split_with(messages, fn msg ->
        msg.role == "system" || msg[:role] == "system"
      end)

    system_prompt =
      case system_messages do
        [] -> nil
        msgs -> Enum.map_join(msgs, "\n", fn msg -> msg.content || msg[:content] end)
      end

    # Convert remaining messages to Anthropic format
    anthropic_messages =
      other_messages
      |> Enum.map(fn msg ->
        role = msg.role || msg[:role]
        content = msg.content || msg[:content]

        %{
          role: if(role == "user", do: "user", else: "assistant"),
          content: content
        }
      end)

    {system_prompt, anthropic_messages}
  end

  defp transform_response(%{"content" => content} = response) do
    # Extract text from Anthropic's content array format
    text_content =
      content
      |> Enum.find_value(fn item ->
        if item["type"] == "text", do: item["text"]
      end) || ""

    # Transform to OpenAI-compatible format
    %{
      "choices" => [
        %{
          "message" => %{
            "role" => "assistant",
            "content" => text_content
          },
          "finish_reason" => response["stop_reason"] || "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => get_in(response, ["usage", "input_tokens"]) || 0,
        "completion_tokens" => get_in(response, ["usage", "output_tokens"]) || 0,
        "total_tokens" =>
          (get_in(response, ["usage", "input_tokens"]) || 0) +
            (get_in(response, ["usage", "output_tokens"]) || 0)
      },
      "model" => response["model"] || @default_model
    }
  end

  defp transform_response(response), do: response

  defp auth_headers do
    api_key = System.fetch_env!("ANTHROPIC_API_KEY")

    [
      {"authorization", "Bearer #{api_key}"},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]
  rescue
    _error in ArgumentError ->
      reraise RuntimeError,
              """
              ANTHROPIC_API_KEY environment variable is required but not set.
              Please set your Anthropic API key:

                export ANTHROPIC_API_KEY=sk-ant-...
              """,
              __STACKTRACE__
  end
end
