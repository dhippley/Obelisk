defmodule Obelisk.Retrieval do
  @moduledoc """
  Vector similarity search and retrieval system using pgvector.

  Provides semantic search across memory chunks with session-scoped and global memory support.
  """

  import Ecto.Query
  alias Obelisk.{Embeddings, Repo, Schemas.MemoryChunk}

  @default_k 8
  @similarity_threshold 0.7

  @doc """
  Perform vector similarity search across global and session-scoped memory chunks.

  ## Parameters
  - `query_text`: The text to search for semantically similar content
  - `session_id`: Session ID to include session-specific memories (can be nil for global only)
  - `k`: Number of top results to return (default: 8)
  - `opts`: Additional options like `:threshold`, `:include_global`

  ## Returns
  List of maps with `:id`, `:text`, `:score`, `:memory_id`, and `:kind` fields.
  Score ranges from 0.0 (dissimilar) to 1.0 (identical).

  ## Examples
      # Search in session + global memories
      Retrieval.retrieve("How to deploy Phoenix?", session_id, 5)
      
      # Search only global memories  
      Retrieval.retrieve("What is Elixir?", nil, 10)
  """
  def retrieve(query_text, session_id \\ nil, k \\ @default_k, opts \\ %{})

  def retrieve(query_text, session_id, k, opts) when is_binary(query_text) do
    case Embeddings.embed_text(query_text) do
      {:ok, embedding} ->
        threshold = Map.get(opts, :threshold, @similarity_threshold)
        include_global = Map.get(opts, :include_global, true)

        query_chunks(embedding, session_id, k, threshold, include_global)

      {:error, reason} ->
        {:error, {:embedding_failed, reason}}
    end
  end

  @doc """
  Search for similar memory chunks by embedding vector.

  Useful when you already have an embedding vector.
  """
  def retrieve_by_embedding(embedding, session_id \\ nil, k \\ @default_k, opts \\ %{}) do
    threshold = Map.get(opts, :threshold, @similarity_threshold)
    include_global = Map.get(opts, :include_global, true)

    query_chunks(embedding, session_id, k, threshold, include_global)
  end

  @doc """
  Get memory chunks for a specific memory record.
  """
  def get_memory_chunks(memory_id) when is_integer(memory_id) do
    from(mc in MemoryChunk,
      where: mc.memory_id == ^memory_id,
      select: %{
        id: mc.id,
        text: mc.text,
        memory_id: mc.memory_id
      }
    )
    |> Repo.all()
  end

  # Private functions

  defp query_chunks(embedding, session_id, k, threshold, include_global) do
    case {session_id, include_global} do
      {nil, _} ->
        query_global_only(embedding, k, threshold)

      {session_id, true} when is_integer(session_id) ->
        query_session_and_global(embedding, session_id, k, threshold)

      {session_id, false} when is_integer(session_id) ->
        query_session_only(embedding, session_id, k, threshold)
    end
  end

  defp query_global_only(embedding, k, threshold) do
    sql = """
    SELECT 
      mc.id,
      mc.text,
      mc.memory_id,
      m.kind,
      m.session_id,
      1 - (mc.embedding <=> $1) AS score
    FROM memory_chunks mc
    INNER JOIN memories m ON mc.memory_id = m.id
    WHERE m.session_id IS NULL
      AND (1 - (mc.embedding <=> $1)) >= $3
    ORDER BY mc.embedding <-> $1
    LIMIT $2
    """

    execute_similarity_query(sql, [embedding, k, threshold])
  end

  defp query_session_and_global(embedding, session_id, k, threshold) do
    sql = """
    SELECT 
      mc.id,
      mc.text,
      mc.memory_id,
      m.kind,
      m.session_id,
      1 - (mc.embedding <=> $1) AS score
    FROM memory_chunks mc
    INNER JOIN memories m ON mc.memory_id = m.id
    WHERE (m.session_id IS NULL OR m.session_id = $2)
      AND (1 - (mc.embedding <=> $1)) >= $4
    ORDER BY mc.embedding <-> $1
    LIMIT $3
    """

    execute_similarity_query(sql, [embedding, session_id, k, threshold])
  end

  defp query_session_only(embedding, session_id, k, threshold) do
    sql = """
    SELECT 
      mc.id,
      mc.text,
      mc.memory_id,
      m.kind,
      m.session_id,
      1 - (mc.embedding <=> $1) AS score
    FROM memory_chunks mc
    INNER JOIN memories m ON mc.memory_id = m.id
    WHERE m.session_id = $2
      AND (1 - (mc.embedding <=> $1)) >= $4
    ORDER BY mc.embedding <-> $1
    LIMIT $3
    """

    execute_similarity_query(sql, [embedding, session_id, k, threshold])
  end

  defp execute_similarity_query(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, text, memory_id, kind, session_id, score] ->
          %{
            id: id,
            text: text,
            memory_id: memory_id,
            kind: String.to_atom(kind),
            session_id: session_id,
            score: Float.round(score, 3)
          }
        end)

      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  end
end
