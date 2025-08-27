defmodule ObeliskWeb.ChatLive do
  @moduledoc """
  LiveView for interactive chat interface with RAG support.

  Features:
  - Real-time chat with streaming responses
  - Session management and history
  - Memory context display
  - Provider switching
  - Observability metrics
  """

  use ObeliskWeb, :live_view

  alias Obelisk.{Chat, Memory, Retrieval}

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to chat updates for real-time functionality
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Obelisk.PubSub, "chat_updates")
    end

    # Initialize with a default session
    session_name = "liveview-session-#{:erlang.system_time()}"
    {:ok, session} = Memory.get_or_create_session(session_name)

    # Load initial chat history
    {:ok, messages} = Chat.get_conversation_history(session.id, %{max_history: 50})

    socket =
      socket
      |> assign(:session, session)
      |> assign(:session_name, session_name)
      |> assign(:messages, messages)
      |> assign(:current_message, "")
      |> assign(:loading, false)
      |> assign(:streaming, false)
      |> assign(:stream_content, "")
      |> assign(:context_results, [])
      |> assign(:stats, %{
        context_used: 0,
        history_included: 0,
        response_time: 0
      })
      |> assign(:sidebar_open, true)
      |> assign(:current_provider, "openai")
      |> assign(:available_providers, LLM.Router.available_providers())

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    session_name = socket.assigns.session_name

    socket =
      socket
      |> assign(:current_message, "")
      |> assign(:loading, true)
      |> assign(:streaming, false)
      |> assign(:stream_content, "")

    # Add user message to UI immediately
    user_msg = %{
      role: :user,
      content: %{text: message},
      inserted_at: NaiveDateTime.utc_now()
    }

    socket = update(socket, :messages, fn msgs -> msgs ++ [user_msg] end)

    # Send message asynchronously to avoid blocking the LiveView
    pid = self()

    Task.start(fn ->
      start_time = System.monotonic_time(:millisecond)

      # Use current provider for the chat request
      chat_opts = %{provider: socket.assigns.current_provider}

      case Chat.send_message(message, session_name, chat_opts) do
        {:ok, result} ->
          end_time = System.monotonic_time(:millisecond)
          response_time = end_time - start_time

          # Get context that was used
          context = Retrieval.retrieve(message, socket.assigns.session.id, 3)

          send(pid, {:chat_response, result, context, response_time})

        {:error, reason} ->
          send(pid, {:chat_error, reason})
      end
    end)

    {:noreply, socket}
  end

  def handle_event("clear_history", _params, socket) do
    session_name = socket.assigns.session_name

    case Chat.clear_history(session_name) do
      {:ok, :cleared} ->
        socket =
          socket
          |> assign(:messages, [])
          |> assign(:context_results, [])
          |> assign(:stats, %{context_used: 0, history_included: 0, response_time: 0})
          |> put_flash(:info, "Chat history cleared")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to clear history")}
    end
  end

  def handle_event("new_session", _params, socket) do
    # Create a new session
    session_name = "liveview-session-#{:erlang.system_time()}"
    {:ok, session} = Memory.get_or_create_session(session_name)

    socket =
      socket
      |> assign(:session, session)
      |> assign(:session_name, session_name)
      |> assign(:messages, [])
      |> assign(:current_message, "")
      |> assign(:context_results, [])
      |> assign(:stats, %{context_used: 0, history_included: 0, response_time: 0})
      |> put_flash(:info, "Started new chat session")

    {:noreply, socket}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, not socket.assigns.sidebar_open)}
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  def handle_event("switch_provider", %{"provider" => provider}, socket) do
    socket =
      socket
      |> assign(:current_provider, provider)
      |> put_flash(:info, "Switched to #{String.capitalize(provider)} provider")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_response, result, context, response_time}, socket) do
    # Add assistant message to UI
    assistant_msg = %{
      role: :assistant,
      content: %{text: result.response},
      inserted_at: NaiveDateTime.utc_now()
    }

    socket =
      socket
      |> update(:messages, fn msgs -> msgs ++ [assistant_msg] end)
      |> assign(:loading, false)
      |> assign(:context_results, format_context_results(context))
      |> assign(:stats, %{
        context_used: result.context_used,
        history_included: result.history_included,
        response_time: response_time
      })

    {:noreply, socket}
  end

  def handle_info({:chat_error, reason}, socket) do
    error_msg = format_chat_error(reason)

    socket =
      socket
      |> assign(:loading, false)
      |> put_flash(:error, "Chat error: #{error_msg}")

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp format_context_results([]), do: []

  defp format_context_results(results) when is_list(results) do
    Enum.map(results, fn result ->
      %{
        text: String.slice(result.text, 0, 200),
        score: Float.round(result.score, 3),
        source: result.kind || "unknown"
      }
    end)
  end

  defp format_context_results(_), do: []

  defp format_chat_error({:llm_failed, reason}), do: "LLM error: #{inspect(reason)}"
  defp format_chat_error({:retrieval_failed, reason}), do: "Retrieval error: #{inspect(reason)}"
  defp format_chat_error({:embedding_failed, reason}), do: "Embedding error: #{inspect(reason)}"
  defp format_chat_error(reason), do: inspect(reason)
end
