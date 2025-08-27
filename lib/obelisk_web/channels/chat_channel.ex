defmodule ObeliskWeb.ChatChannel do
  @moduledoc """
  Phoenix Channel for real-time chat with RAG support.

  Provides bi-directional WebSocket communication for chat sessions.
  Integrates with the existing Chat module for RAG functionality.
  """

  use Phoenix.Channel

  alias Obelisk.{Chat, Memory}
  require Logger

  @doc """
  Join a chat session channel.

  ## Channel Topic Format
  - `"chat:session_name"` - Join a named session
  - `"chat:global"` - Join the global chat (no session persistence)
  """
  def join("chat:" <> session_name, _params, socket) do
    Logger.info("User joined chat session: #{session_name}")

    # Ensure session exists and get its info
    case Memory.get_or_create_session(session_name) do
      {:ok, session} ->
        # Get recent chat history to send to the joining client
        case Chat.get_conversation_history(session.id, %{max_history: 20}) do
          {:ok, history} ->
            socket =
              socket
              |> assign(:session_name, session_name)
              |> assign(:session_id, session.id)

            # Send chat history to the joining client
            send(self(), {:after_join, format_messages(history)})

            {:ok, socket}

          {:error, reason} ->
            Logger.error("Failed to load chat history for session #{session_name}: #{inspect(reason)}")
            {:error, %{reason: "Failed to load chat history"}}
        end

      {:error, reason} ->
        Logger.error("Failed to create/get session #{session_name}: #{inspect(reason)}")
        {:error, %{reason: "Failed to access session"}}
    end
  end

  def join(_topic, _params, _socket) do
    {:error, %{reason: "Invalid chat topic format. Use 'chat:session_name'"}}
  end

  @doc """
  Handle incoming messages from clients.

  Supported message types:
  - "new_message" - Send a chat message with RAG
  - "stream_message" - Send a streaming chat message
  - "typing" - Send typing indicators
  - "get_history" - Request chat history
  - "clear_history" - Clear chat history
  """
  def handle_in("new_message", %{"message" => message} = params, socket) do
    session_name = socket.assigns.session_name
    options = Map.get(params, "options", %{})

    Logger.debug("Processing message in session #{session_name}: #{String.slice(message, 0, 50)}...")

    # Send typing indicator to all users in the channel
    broadcast(socket, "typing", %{
      user: "assistant",
      typing: true
    })

    case Chat.send_message(message, session_name, options) do
      {:ok, result} ->
        # Stop typing indicator
        broadcast(socket, "typing", %{
          user: "assistant",
          typing: false
        })

        # Broadcast the user message to all clients
        broadcast(socket, "new_message", %{
          role: "user",
          content: %{text: message},
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          session: session_name
        })

        # Broadcast the assistant response to all clients
        broadcast(socket, "new_message", %{
          role: "assistant",
          content: %{text: result.response},
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          session: session_name,
          metadata: %{
            context_used: result.context_used,
            history_included: result.history_included
          }
        })

        # Reply to the sender with additional metadata
        {:reply, {:ok, %{
          response: result.response,
          context_used: result.context_used,
          history_included: result.history_included,
          session: session_name
        }}, socket}

      {:error, reason} ->
        # Stop typing indicator
        broadcast(socket, "typing", %{
          user: "assistant",
          typing: false
        })

        error_message = format_error(reason)
        Logger.error("Chat error in session #{session_name}: #{error_message}")

        # Reply with error to the sender
        {:reply, {:error, %{reason: error_message}}, socket}
    end
  end

  def handle_in("stream_message", %{"message" => message} = params, socket) do
    session_name = socket.assigns.session_name
    options = Map.get(params, "options", %{})

    # Send typing indicator
    broadcast(socket, "typing", %{
      user: "assistant",
      typing: true
    })

    # Start streaming response
    push(socket, "stream_start", %{
      session: session_name,
      message: message
    })

    # Check for errors first before confirming streaming
    case Chat.send_message(message, session_name, options) do
      {:ok, result} ->
        # Send immediate reply to confirm streaming started
        # Then spawn async process for the actual streaming
        spawn(fn ->
          # Simulate streaming by breaking response into chunks
          response_words = String.split(result.response, " ")

          # Send each word as a stream chunk
          Enum.each(response_words, fn word ->
            push(socket, "stream_chunk", %{
              content: word <> " ",
              session: session_name
            })
            Process.sleep(50)  # Simulate typing delay
          end)

          # Send stream completion
          push(socket, "stream_complete", %{
            session: session_name,
            metadata: %{
              context_used: result.context_used,
              history_included: result.history_included
            }
          })

          # Stop typing indicator
          broadcast(socket, "typing", %{
            user: "assistant",
            typing: false
          })
        end)

        {:reply, {:ok, %{streaming: true, session: session_name}}, socket}

      {:error, reason} ->
        # Stop typing indicator and send error
        broadcast(socket, "typing", %{
          user: "assistant",
          typing: false
        })

        push(socket, "stream_error", %{
          error: format_error(reason),
          session: session_name
        })

        {:reply, {:error, %{reason: format_error(reason)}}, socket}
    end
  end

  def handle_in("typing", %{"typing" => typing} = params, socket) do
    user = Map.get(params, "user", "anonymous")

    # Broadcast typing status to other users in the channel
    broadcast_from(socket, "typing", %{
      user: user,
      typing: typing
    })

    {:noreply, socket}
  end

  def handle_in("get_history", params, socket) do
    session_id = socket.assigns.session_id
    max_history = Map.get(params, "max_history", 50)

    case Chat.get_conversation_history(session_id, %{max_history: max_history}) do
      {:ok, history} ->
        {:reply, {:ok, %{history: format_messages(history)}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: "Failed to load history: #{inspect(reason)}"}}, socket}
    end
  end

  def handle_in("clear_history", _params, socket) do
    session_name = socket.assigns.session_name

    case Chat.clear_history(session_name) do
      {:ok, :cleared} ->
        # Broadcast history clear to all users in the channel
        broadcast(socket, "history_cleared", %{
          session: session_name,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        {:reply, {:ok, %{cleared: true}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: "Failed to clear history: #{inspect(reason)}"}}, socket}
    end
  end

  # Callbacks

  @doc """
  Handle user leaving the channel.
  """
  def terminate(reason, socket) do
    session_name = socket.assigns[:session_name]
    Logger.info("User left chat session #{session_name}, reason: #{inspect(reason)}")
    :ok
  end

  # Private functions

  def handle_info({:after_join, history}, socket) do
    # Send chat history to the client after they join
    push(socket, "chat_history", %{history: history})
    {:noreply, socket}
  end

  defp format_messages(history) do
    Enum.map(history, fn msg ->
      %{
        role: msg.role,
        content: msg.content,
        timestamp: msg.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601(),
        tool_name: Map.get(msg, :tool_name)
      }
    end)
  end

  defp format_error({:llm_failed, reason}), do: "LLM error: #{inspect(reason)}"
  defp format_error({:retrieval_failed, reason}), do: "Retrieval error: #{inspect(reason)}"
  defp format_error({:embedding_failed, reason}), do: "Embedding error: #{inspect(reason)}"
  defp format_error({:unexpected_error, reason}), do: "Unexpected error: #{inspect(reason)}"
  defp format_error(:llm_failed), do: "LLM error: llm_failed"
  defp format_error(:retrieval_failed), do: "Retrieval error: retrieval_failed"
  defp format_error(:embedding_failed), do: "Embedding error: embedding_failed"
  defp format_error(reason), do: inspect(reason)
end
