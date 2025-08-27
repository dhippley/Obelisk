defmodule Obelisk.Tools.Chat do
  @moduledoc """
  Tool for interacting with Obelisk's chat system.

  This tool allows AI agents to send messages to the chat system and receive
  responses, integrating with the RAG (Retrieval-Augmented Generation) pipeline.
  """

  @behaviour Obelisk.Tool

  @impl true
  def spec do
    %{
      name: "chat",
      description: "Send a message to the Obelisk chat system and get an AI response",
      params: %{
        type: "object",
        properties: %{
          message: %{
            type: "string",
            description: "The message to send to the chat system"
          },
          session_name: %{
            type: "string",
            description: "Optional session name for the conversation (default: from context)"
          },
          provider: %{
            type: "string",
            enum: ["openai", "anthropic", "ollama"],
            description: "LLM provider to use (default: openai)"
          },
          model: %{
            type: "string",
            description: "Specific model to use (e.g., gpt-4o-mini, claude-3-5-sonnet-20241022)"
          }
        },
        required: ["message"]
      }
    }
  end

  @impl true
  def call(params, ctx) do
    message = Map.get(params, "message")

    session_name =
      Map.get(params, "session_name") ||
        Map.get(ctx, :session_id) ||
        "tool-session-#{:erlang.system_time()}"

    # Build chat options
    chat_opts = %{}

    chat_opts =
      if provider = Map.get(params, "provider"),
        do: Map.put(chat_opts, :provider, provider),
        else: chat_opts

    chat_opts =
      if model = Map.get(params, "model"), do: Map.put(chat_opts, :model, model), else: chat_opts

    try do
      case Obelisk.Chat.send_message(message, session_name, chat_opts) do
        {:ok, result} ->
          {:ok,
           %{
             response: result.response,
             session: result.session,
             context_used: result.context_used,
             history_included: result.history_included,
             provider: Map.get(chat_opts, :provider, "openai"),
             model: Map.get(chat_opts, :model),
             timestamp: DateTime.utc_now()
           }}

        {:error, reason} ->
          {:error, "Chat failed: #{format_chat_error(reason)}"}
      end
    rescue
      error ->
        {:error, "Chat system error: #{inspect(error)}"}
    end
  end

  defp format_chat_error({:llm_failed, reason}), do: "LLM error: #{inspect(reason)}"
  defp format_chat_error({:session_error, reason}), do: "Session error: #{inspect(reason)}"
  defp format_chat_error(reason), do: inspect(reason)
end
