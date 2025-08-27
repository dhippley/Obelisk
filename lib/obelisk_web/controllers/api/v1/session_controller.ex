defmodule ObeliskWeb.Api.V1.SessionController do
  @moduledoc """
  API controller for session management and inspection.
  """

  use ObeliskWeb, :controller

  alias Obelisk.{Chat, Memory}

  @doc """
  Get session details including messages and memory context.
  """
  def show(conn, %{"id" => session_id}) do
    case Memory.get_or_create_session(session_id) do
      {:ok, session} ->
        # Get conversation history and associated memories
        {:ok, history} = Chat.get_conversation_history(session.id, %{max_history: 100})
        memories = Memory.list_memories(session.id)

        json(conn, %{
          id: session.id,
          name: session.name,
          metadata: session.metadata,
          created_at: session.inserted_at,
          updated_at: session.updated_at,
          messages: format_messages(history),
          memories: format_memories(memories),
          stats: %{
            message_count: length(history),
            memory_count: length(memories),
            last_activity: get_last_activity(history)
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found: #{inspect(reason)}"})
    end
  end

  @doc """
  List all sessions with basic info.
  """
  def index(conn, params) do
    limit = Map.get(params, "limit", 20) |> ensure_integer() |> min(100)

    # For now, we'll implement a simple approach
    # In a real implementation, you'd have a proper sessions query
    sessions = get_recent_sessions(limit)

    json(conn, %{
      sessions: sessions,
      count: length(sessions)
    })
  end

  @doc """
  Create a new session.
  """
  def create(conn, params) do
    name = Map.get(params, "name", "session-#{:erlang.system_time()}")
    metadata = Map.get(params, "metadata", %{})

    case Memory.get_or_create_session(name, metadata) do
      {:ok, session} ->
        conn
        |> put_status(:created)
        |> json(%{
          id: session.id,
          name: session.name,
          metadata: session.metadata,
          created_at: session.inserted_at,
          updated_at: session.updated_at
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create session: #{inspect(reason)}"})
    end
  end

  @doc """
  Delete a session and all its data.
  """
  def delete(conn, %{"id" => session_id}) do
    case Memory.get_or_create_session(session_id) do
      {:ok, session} ->
        # Clear chat history
        case Chat.clear_history(session.name) do
          {:ok, :cleared} ->
            # Delete memories (simplified - in production you'd want proper cascade deletion)
            memories = Memory.list_memories(session.id)

            Enum.each(memories, fn memory ->
              Memory.delete_memory(memory.id)
            end)

            # Delete session (would need to implement this in Memory module)
            json(conn, %{message: "Session data cleared", session_id: session_id})

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to delete session: #{inspect(reason)}"})
        end

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found: #{inspect(reason)}"})
    end
  end

  # Private functions

  defp format_messages(history) do
    Enum.map(history, fn msg ->
      %{
        id: Map.get(msg, :id),
        role: msg.role,
        content: msg.content,
        tool_name: Map.get(msg, :tool_name),
        timestamp: msg.inserted_at
      }
    end)
  end

  defp format_memories(memories) do
    Enum.map(memories, fn memory ->
      %{
        id: memory.id,
        text: truncate_text(memory.text, 200),
        kind: memory.kind,
        metadata: memory.metadata,
        has_embedding: not is_nil(memory.embedding),
        created_at: memory.inserted_at
      }
    end)
  end

  defp get_last_activity([]), do: nil

  defp get_last_activity(history) do
    history
    |> List.last()
    |> Map.get(:inserted_at)
  end

  defp get_recent_sessions(limit) do
    # This is a simplified implementation
    # In production, you'd query the sessions table properly
    []
    |> Enum.take(limit)
  end

  defp truncate_text(text, max_length) when byte_size(text) <= max_length, do: text

  defp truncate_text(text, max_length) do
    String.slice(text, 0, max_length - 3) <> "..."
  end

  defp ensure_integer(value) when is_integer(value), do: value

  defp ensure_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 20
    end
  end

  defp ensure_integer(_), do: 20
end
