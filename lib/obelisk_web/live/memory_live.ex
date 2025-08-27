defmodule ObeliskWeb.MemoryLive do
  @moduledoc """
  LiveView for memory inspection and management.

  Features:
  - Browse and search stored memories
  - View memory details and metadata
  - Delete and manage memories
  - Session-scoped vs global memory filtering
  - Memory statistics and analytics
  """

  use ObeliskWeb, :live_view

  alias Obelisk.{Memory, Retrieval}
  import Ecto.Query

  @default_per_page 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Obelisk.PubSub, "memory_updates")
    end

    socket =
      socket
      |> assign(:memories, [])
      |> assign(:search_query, "")
      |> assign(:selected_memory, nil)
      # "all", "global", "session"
      |> assign(:filter_scope, "all")
      |> assign(:current_session_id, nil)
      |> assign(:page, 1)
      |> assign(:per_page, @default_per_page)
      |> assign(:total_count, 0)
      |> assign(:loading, false)
      |> assign(:show_details, false)
      |> assign(:search_results, [])
      |> assign(:search_active, false)
      |> assign(:stats, %{
        total_memories: 0,
        total_chunks: 0,
        sessions_with_memories: 0,
        global_memories: 0
      })

    {:ok, load_memories(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = String.to_integer(params["page"] || "1")

    socket =
      socket
      |> assign(:page, page)
      |> load_memories()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => ""}}, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> assign(:search_active, false)
      |> assign(:search_results, [])
      |> load_memories()

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket = assign(socket, :search_query, query)

    if String.length(query) >= 2 do
      socket =
        socket
        |> assign(:loading, true)
        |> assign(:search_active, true)

      # Perform semantic search
      pid = self()

      Task.start(fn ->
        try do
          results = Retrieval.retrieve(query, nil, 50)
          send(pid, {:search_results, results})
        catch
          _type, _error ->
            # Fallback to text search if embedding fails
            results = text_search_memories(query, 50)
            send(pid, {:search_results, results})
        end
      end)

      {:noreply, socket}
    else
      {:noreply, assign(socket, :search_active, false)}
    end
  end

  def handle_event("filter_scope", %{"scope" => scope}, socket) do
    socket =
      socket
      |> assign(:filter_scope, scope)
      |> assign(:page, 1)
      |> load_memories()

    {:noreply, socket}
  end

  def handle_event("view_memory", %{"id" => id}, socket) do
    memory_id = String.to_integer(id)

    case get_memory_with_chunks(memory_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Memory not found")}

      memory ->
        socket =
          socket
          |> assign(:selected_memory, memory)
          |> assign(:show_details, true)

        {:noreply, socket}
    end
  end

  def handle_event("close_details", _params, socket) do
    socket =
      socket
      |> assign(:selected_memory, nil)
      |> assign(:show_details, false)

    {:noreply, socket}
  end

  def handle_event("delete_memory", %{"id" => id}, socket) do
    memory_id = String.to_integer(id)

    case Memory.delete_memory(memory_id) do
      {:ok, _} ->
        socket =
          socket
          |> assign(:selected_memory, nil)
          |> assign(:show_details, false)
          |> put_flash(:info, "Memory deleted successfully")
          |> load_memories()

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete memory")}
    end
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_memories(socket)}
  end

  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:search_query, "")
      |> assign(:search_active, false)
      |> assign(:search_results, [])
      |> load_memories()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:search_results, results}, socket) do
    formatted_results = format_search_results(results)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:search_results, formatted_results)

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp load_memories(socket) do
    %{
      filter_scope: scope,
      page: page,
      per_page: per_page,
      current_session_id: session_id
    } = socket.assigns

    # Get memories with pagination
    query = build_memories_query(scope, session_id)

    offset = (page - 1) * per_page

    memories =
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> order_by([m], desc: m.inserted_at)
      |> preload(:memory_chunks)
      |> Obelisk.Repo.all()

    # Get total count
    total_count = query |> Obelisk.Repo.aggregate(:count, :id)

    # Get statistics
    stats = get_memory_stats()

    socket
    |> assign(:memories, memories)
    |> assign(:total_count, total_count)
    |> assign(:stats, stats)
    |> assign(:loading, false)
  end

  defp build_memories_query("global", _session_id) do
    from(m in Obelisk.Schemas.Memory, where: is_nil(m.session_id))
  end

  defp build_memories_query("session", session_id) when not is_nil(session_id) do
    from(m in Obelisk.Schemas.Memory, where: m.session_id == ^session_id)
  end

  defp build_memories_query("all", _session_id) do
    from(m in Obelisk.Schemas.Memory)
  end

  defp get_memory_with_chunks(memory_id) do
    Obelisk.Schemas.Memory
    |> preload(:memory_chunks)
    |> Obelisk.Repo.get(memory_id)
  end

  defp text_search_memories(query, limit) do
    sql = """
    SELECT m.id, m.text, m.kind, m.metadata, m.inserted_at,
           ts_rank(to_tsvector('english', m.text), plainto_tsquery('english', $1)) as rank
    FROM memories m
    WHERE to_tsvector('english', m.text) @@ plainto_tsquery('english', $1)
    ORDER BY rank DESC
    LIMIT $2
    """

    case Ecto.Adapters.SQL.query(Obelisk.Repo, sql, [query, limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, text, kind, metadata, inserted_at, rank] ->
          %{
            id: id,
            text: text,
            kind: kind,
            metadata: metadata,
            inserted_at: inserted_at,
            score: Float.round(rank, 3)
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp format_search_results(results) do
    Enum.map(results, fn result ->
      %{
        id: result.id || 0,
        text: String.slice(result.text, 0, 200),
        kind: result.kind || "unknown",
        score: Float.round(result.score, 3),
        full_text: result.text
      }
    end)
  end

  defp get_memory_stats do
    total_memories = from(m in Obelisk.Schemas.Memory) |> Obelisk.Repo.aggregate(:count, :id)

    total_chunks = from(c in Obelisk.Schemas.MemoryChunk) |> Obelisk.Repo.aggregate(:count, :id)

    global_memories =
      from(m in Obelisk.Schemas.Memory, where: is_nil(m.session_id))
      |> Obelisk.Repo.aggregate(:count, :id)

    sessions_with_memories =
      from(m in Obelisk.Schemas.Memory, where: not is_nil(m.session_id))
      |> select([m], m.session_id)
      |> distinct(true)
      |> Obelisk.Repo.aggregate(:count, :session_id)

    %{
      total_memories: total_memories,
      total_chunks: total_chunks,
      global_memories: global_memories,
      sessions_with_memories: sessions_with_memories
    }
  end

  defp truncate_text(text, length) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end
end
