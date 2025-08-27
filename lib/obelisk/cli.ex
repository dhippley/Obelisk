defmodule Obelisk.CLI do
  @moduledoc """
  Interactive REPL for Obelisk chat with RAG.

  Provides a command-line interface for conversing with the AI assistant
  using stored memories for context.
  """

  alias Obelisk.{Chat, Memory}

  @default_session "default"
  @prompt_prefix "obelisk> "
  @welcome_message """

  🏛️  Obelisk Chat with RAG

  Type your message and press Enter to chat.
  Commands:
    /help     - Show this help
    /session  - Show current session info
    /clear    - Clear conversation history
    /quit     - Exit (or Ctrl+C)

  """

  def repl(session_name \\ @default_session) do
    IO.puts(@welcome_message)
    IO.puts("Session: #{session_name}")
    IO.puts(String.duplicate("─", 50))

    # Ensure session exists and show any existing context
    case Memory.get_or_create_session(session_name) do
      {:ok, session} ->
        show_session_info(session, false)
        repl_loop(session_name)

      {:error, reason} ->
        IO.puts("Error creating session: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp repl_loop(session_name) do
    case IO.gets(@prompt_prefix) do
      :eof ->
        IO.puts("\nGoodbye! 👋")

      {:error, reason} ->
        IO.puts("Input error: #{inspect(reason)}")
        repl_loop(session_name)

      input when is_binary(input) ->
        input
        |> String.trim()
        |> handle_input(session_name)
        |> case do
          :continue -> repl_loop(session_name)
          :quit -> IO.puts("Goodbye! 👋")
        end
    end
  end

  defp handle_input("", _session_name), do: :continue

  defp handle_input("/help", _session_name) do
    IO.puts(@welcome_message)
    :continue
  end

  defp handle_input("/quit", _session_name), do: :quit
  defp handle_input("/exit", _session_name), do: :quit
  defp handle_input("/q", _session_name), do: :quit

  defp handle_input("/session", session_name) do
    case Memory.get_or_create_session(session_name) do
      {:ok, session} -> show_session_info(session, true)
      {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
    end

    :continue
  end

  defp handle_input("/clear", session_name) do
    case Chat.clear_history(session_name) do
      {:ok, :cleared} ->
        IO.puts("✅ Conversation history cleared.")

      {:error, reason} ->
        IO.puts("❌ Error clearing history: #{inspect(reason)}")
    end

    :continue
  end

  defp handle_input(message, session_name) when is_binary(message) do
    # Add some space
    IO.puts("")
    IO.puts("💭 Thinking...")

    start_time = System.monotonic_time()

    case Chat.send_message(message, session_name) do
      {:ok, result} ->
        end_time = System.monotonic_time()
        duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

        IO.puts("🤖 #{result.response}")
        IO.puts("")

        # Show context info
        context_info = [
          "⏱️  #{duration_ms}ms",
          "📚 #{result.context_used} memories",
          "💬 #{result.history_included} history"
        ]

        IO.puts("   " <> Enum.join(context_info, " • "))
        IO.puts("")

      {:error, reason} ->
        IO.puts("❌ Error: #{format_error(reason)}")
        IO.puts("")
    end

    :continue
  end

  defp show_session_info(session, verbose) do
    if verbose do
      IO.puts("")
      IO.puts("Session: #{session.name}")
      IO.puts("Created: #{session.inserted_at}")

      # Show memory count
      memories = Memory.list_memories(session.id)
      IO.puts("Memories: #{length(memories)}")

      # Show recent history
      case Chat.get_conversation_history(session.id, %{max_history: 5}) do
        {:ok, []} ->
          IO.puts("History: No messages yet")

        {:ok, history} ->
          IO.puts("Recent history: #{length(history)} messages")
          print_recent_history(history)
      end

      IO.puts("")
    end
  end

  defp print_recent_history(history) do
    history
    # Last 2 messages
    |> Enum.take(-2)
    |> Enum.each(fn msg ->
      role_icon = if msg.role == :user, do: "👤", else: "🤖"

      content =
        String.slice(msg.content, 0, 50) <>
          if String.length(msg.content) > 50, do: "...", else: ""

      IO.puts("  #{role_icon} #{content}")
    end)
  end

  defp format_error({:llm_failed, reason}), do: "LLM error: #{inspect(reason)}"
  defp format_error({:retrieval_failed, reason}), do: "Retrieval error: #{inspect(reason)}"
  defp format_error({:embedding_failed, reason}), do: "Embedding error: #{inspect(reason)}"
  defp format_error({:unexpected_error, reason}), do: "Unexpected error: #{inspect(reason)}"
  defp format_error(reason), do: inspect(reason)
end
