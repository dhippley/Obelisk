defmodule ObeliskWeb.Api.V1.MemoryController do
  @moduledoc """
  API controller for memory operations including search and storage.

  Supports both regular JSON responses and Server-Sent Events (SSE) streaming
  for real-time search results.
  """

  use ObeliskWeb, :controller

  alias Obelisk.{Memory, Retrieval}

  @doc """
  Search memories using vector similarity.

  ## Request Body
  ```json
  {
    "query": "What is Phoenix?",
    "session_id": "optional-session-id",
    "k": 5,
    "threshold": 0.7,
    "include_global": true,
    "stream": false
  }
  ```
  """
  def search(conn, params) do
    query = Map.get(params, "query")
    session_id = Map.get(params, "session_id")
    k = Map.get(params, "k", 5)
    threshold = Map.get(params, "threshold", 0.0)
    include_global = Map.get(params, "include_global", true)
    stream = Map.get(params, "stream", false)

    cond do
      is_nil(query) or query == "" ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "query is required"})

      stream ->
        handle_streaming_search(conn, query, session_id, k, threshold, include_global)

      true ->
        handle_regular_search(conn, query, session_id, k, threshold, include_global)
    end
  end

  @doc """
  Store a new memory.

  ## Request Body
  ```json
  {
    "text": "Elixir is a functional programming language",
    "kind": "fact",
    "metadata": {"source": "api"},
    "session_id": "optional-session-id",
    "async": true
  }
  ```
  """
  def create(conn, params) do
    text = Map.get(params, "text")
    kind = Map.get(params, "kind", "note") |> String.to_existing_atom()
    metadata = Map.get(params, "metadata", %{})
    session_id = Map.get(params, "session_id")
    use_async = Map.get(params, "async", false)

    if is_nil(text) or text == "" do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "text is required"})
    else
      memory_attrs = %{
        text: text,
        kind: kind,
        metadata: metadata,
        session_id: get_session_id(session_id),
        async: use_async
      }

      case Memory.store_memory_simple(memory_attrs) do
        {:ok, memory} ->
          conn
          |> put_status(:created)
          |> json(%{
            id: memory.id,
            text: memory.text,
            kind: memory.kind,
            metadata: memory.metadata,
            session_id: memory.session_id,
            has_embedding: not is_nil(memory.embedding),
            inserted_at: memory.inserted_at
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Validation failed", details: format_changeset_errors(changeset)})
      end
    end
  end

  @doc """
  List memories for a session.
  """
  def index(conn, params) do
    session_id = Map.get(params, "session_id")
    limit = Map.get(params, "limit", 50) |> ensure_integer() |> min(100)

    memories =
      case get_session_id(session_id) do
        nil ->
          Memory.list_memories(nil)

        sid ->
          case Memory.get_or_create_session("session-#{sid}") do
            {:ok, session} -> Memory.list_memories(session.id)
            {:error, _} -> []
          end
      end

    formatted_memories =
      memories
      |> Enum.take(limit)
      |> Enum.map(&format_memory/1)

    json(conn, %{
      memories: formatted_memories,
      count: length(formatted_memories),
      session_id: session_id
    })
  end

  # Private functions

  defp handle_regular_search(conn, query, session_id, k, threshold, include_global) do
    opts = %{
      threshold: threshold,
      include_global: include_global
    }

    case Retrieval.retrieve(query, get_session_id(session_id), k, opts) do
      results when is_list(results) ->
        json(conn, %{
          query: query,
          results: format_search_results(results),
          count: length(results),
          session_id: session_id,
          parameters: %{
            k: k,
            threshold: threshold,
            include_global: include_global
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Search failed: #{inspect(reason)}"})
    end
  end

  defp handle_streaming_search(conn, query, session_id, k, threshold, include_global) do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("access-control-allow-origin", "*")
    |> send_chunked(:ok)
    |> stream_search_response(query, session_id, k, threshold, include_global)
  end

  defp stream_search_response(conn, query, session_id, k, threshold, include_global) do
    # Send start event
    send_sse_event(conn, "start", %{
      query: query,
      session_id: session_id
    })

    opts = %{
      threshold: threshold,
      include_global: include_global
    }

    case Retrieval.retrieve(query, get_session_id(session_id), k, opts) do
      results when is_list(results) ->
        # Stream results one by one
        results
        |> format_search_results()
        |> Enum.each(fn result ->
          send_sse_event(conn, "result", result)
          # Simulate streaming delay
          Process.sleep(100)
        end)

        # Send completion
        send_sse_event(conn, "done", %{
          count: length(results),
          query: query
        })

      {:error, reason} ->
        send_sse_event(conn, "error", %{error: "Search failed: #{inspect(reason)}"})
    end

    conn
  end

  defp send_sse_event(conn, event_type, data) do
    event_data =
      %{type: event_type, data: data}
      |> Jason.encode!()

    chunk(conn, "data: #{event_data}\n\n")
  end

  defp get_session_id(nil), do: nil

  defp get_session_id(session_id) when is_binary(session_id) do
    case Memory.get_or_create_session(session_id) do
      {:ok, session} -> session.id
      {:error, _} -> nil
    end
  end

  defp format_search_results(results) do
    Enum.map(results, fn result ->
      %{
        id: result.id,
        text: result.text,
        score: Float.round(result.score, 4),
        memory_id: result.memory_id,
        kind: result.kind,
        session_id: result.session_id
      }
    end)
  end

  defp format_memory(memory) do
    %{
      id: memory.id,
      text: memory.text,
      kind: memory.kind,
      metadata: memory.metadata,
      session_id: memory.session_id,
      has_embedding: not is_nil(memory.embedding),
      inserted_at: memory.inserted_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp ensure_integer(value) when is_integer(value), do: value

  defp ensure_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 50
    end
  end

  defp ensure_integer(_), do: 50
end
