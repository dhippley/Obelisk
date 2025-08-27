defmodule ObeliskWeb.Api.V1.ChatController do
  @moduledoc """
  API controller for chat interactions with RAG support.

  Supports both regular JSON responses and Server-Sent Events (SSE) streaming.
  """

  use ObeliskWeb, :controller

  alias Obelisk.{Chat, Memory}

  @doc """
  Handle chat messages with optional streaming response.

  ## Request Body
  ```json
  {
    "message": "What is Elixir?",
    "session_id": "optional-session-name",
    "stream": false,
    "options": {
      "provider": "openai",
      "model": "gpt-4o-mini",
      "retrieval_k": 5,
      "max_history": 10
    }
  }
  ```

  ## Available Providers
  - `openai`: GPT-4, GPT-3.5-turbo, GPT-4o-mini
  - `anthropic`: Claude-3.5-Sonnet (requires ANTHROPIC_API_KEY)
  - `ollama`: Local models (requires Ollama server)
  """
  def create(conn, params) do
    message = Map.get(params, "message")
    session_id = Map.get(params, "session_id", "api-session-#{:erlang.system_time()}")
    stream = Map.get(params, "stream", false)
    options = Map.get(params, "options", %{})

    cond do
      is_nil(message) or message == "" ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "message is required"})

      stream ->
        handle_streaming_chat(conn, message, session_id, options)

      true ->
        handle_regular_chat(conn, message, session_id, options)
    end
  end

  @doc """
  Get chat history for a session.
  """
  def show(conn, %{"session_id" => session_id}) do
    case Memory.get_or_create_session(session_id) do
      {:ok, session} ->
        {:ok, history} = Chat.get_conversation_history(session.id)

        json(conn, %{
          session_id: session_id,
          messages: format_messages(history)
        })

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found: #{inspect(reason)}"})
    end
  end

  # Private functions

  defp handle_regular_chat(conn, message, session_id, options) do
    start_time = System.monotonic_time(:millisecond)

    case Chat.send_message(message, session_id, options) do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        processing_time = end_time - start_time

        json(conn, %{
          response: result.response,
          session_id: result.session,
          provider: Map.get(options, "provider") || Map.get(options, :provider) || "openai",
          context_used: result.context_used,
          history_included: result.history_included,
          metadata: %{
            processing_time_ms: processing_time
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: format_error(reason)})
    end
  end

  defp handle_streaming_chat(conn, message, session_id, options) do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("access-control-allow-origin", "*")
    |> send_chunked(:ok)
    |> stream_chat_response(message, session_id, options)
  end

  defp stream_chat_response(conn, message, session_id, options) do
    # Send initial event
    send_sse_event(conn, "start", %{
      session_id: session_id,
      message: message
    })

    # For now, we'll simulate streaming by sending the full response
    # In a real implementation, you'd integrate with streaming LLM APIs
    case Chat.send_message(message, session_id, options) do
      {:ok, result} ->
        # Send response chunks (simulated streaming)
        result.response
        |> String.split(" ")
        |> Enum.each(fn word ->
          send_sse_event(conn, "token", %{content: word <> " "})
          # Simulate typing delay
          Process.sleep(50)
        end)

        # Send completion event
        send_sse_event(conn, "done", %{
          session_id: result.session,
          context_used: result.context_used,
          history_included: result.history_included
        })

      {:error, reason} ->
        send_sse_event(conn, "error", %{error: format_error(reason)})
    end

    conn
  end

  defp send_sse_event(conn, event_type, data) do
    event_data =
      %{type: event_type, data: data}
      |> Jason.encode!()

    chunk(conn, "data: #{event_data}\n\n")
  end

  defp format_messages(history) do
    Enum.map(history, fn msg ->
      %{
        role: msg.role,
        content: msg.content,
        timestamp: msg.inserted_at,
        tool_name: Map.get(msg, :tool_name)
      }
    end)
  end

  defp format_error({:llm_failed, reason}), do: "LLM error: #{inspect(reason)}"
  defp format_error({:retrieval_failed, reason}), do: "Retrieval error: #{inspect(reason)}"
  defp format_error({:embedding_failed, reason}), do: "Embedding error: #{inspect(reason)}"
  defp format_error({:unexpected_error, reason}), do: "Unexpected error: #{inspect(reason)}"
  defp format_error(reason), do: inspect(reason)
end
