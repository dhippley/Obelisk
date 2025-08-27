defmodule Obelisk.Memory do
  @moduledoc """
  Memory management and ingestion system.

  Handles storage of memories with automatic chunking and embedding generation.
  """

  import Ecto.Query
  alias Obelisk.{Embeddings, Repo}
  alias Obelisk.Schemas.{Memory, MemoryChunk, Session}

  @default_chunk_size 1000
  @chunk_overlap 100

  @doc """
  Store a memory with automatic chunking and embedding generation.

  ## Parameters
  - `attrs`: Map with `:text`, `:kind`, `:session_id`, `:metadata` fields
  - `opts`: Options like `:chunk_size`, `:chunk_overlap`

  ## Examples
      Memory.store_memory(%{
        text: "Phoenix is a web framework for Elixir...",
        kind: :doc,
        session_id: 1,
        metadata: %{source: "docs.phoenixframework.org"}
      })
  """
  def store_memory(attrs, opts \\ %{}) do
    chunk_size = Map.get(opts, :chunk_size, @default_chunk_size)
    chunk_overlap = Map.get(opts, :chunk_overlap, @chunk_overlap)

    Repo.transaction(fn ->
      with {:ok, memory} <- create_memory(attrs),
           {:ok, memory_with_chunks} <-
             create_chunks(memory, attrs.text, chunk_size, chunk_overlap) do
        memory_with_chunks
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Store a memory without automatic chunking (stores as single chunk).
  """
  def store_memory_simple(attrs) do
    Repo.transaction(fn ->
      with {:ok, memory} <- create_memory(attrs),
           {:ok, embedding} <- Embeddings.embed_text(attrs.text),
           {:ok, chunk} <- create_single_chunk(memory, attrs.text, embedding) do
        %{memory | memory_chunks: [chunk]}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Get a session or create it if it doesn't exist.
  """
  def get_or_create_session(name, metadata \\ %{}) do
    case Repo.get_by(Session, name: name) do
      nil ->
        %Session{name: name, metadata: metadata}
        |> Repo.insert()

      session ->
        {:ok, session}
    end
  end

  @doc """
  List all memories for a session (or global if session_id is nil).
  """
  def list_memories(session_id \\ nil) do
    query = from(m in Memory,
      preload: [:memory_chunks],
      order_by: [desc: m.inserted_at]
    )
    
    query = 
      if session_id do
        from(m in query, where: m.session_id == ^session_id)
      else
        from(m in query, where: is_nil(m.session_id))
      end
    
    Repo.all(query)
  end

  @doc """
  Delete a memory and all its chunks.
  """
  def delete_memory(memory_id) when is_integer(memory_id) do
    case Repo.get(Memory, memory_id) do
      nil -> {:error, :not_found}
      memory -> Repo.delete(memory)
    end
  end

  # Private functions

  defp create_memory(attrs) do
    with {:ok, embedding} <- Embeddings.embed_text(attrs.text) do
      %Memory{}
      |> Memory.changeset(Map.put(attrs, :embedding, embedding))
      |> Repo.insert()
    end
  end

  defp create_chunks(memory, text, chunk_size, chunk_overlap) do
    text
    |> chunk_text(chunk_size, chunk_overlap)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {chunk_text, index}, {:ok, chunks} ->
      case create_memory_chunk(memory, chunk_text, index) do
        {:ok, chunk} -> {:cont, {:ok, [chunk | chunks]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, chunks} -> {:ok, %{memory | memory_chunks: Enum.reverse(chunks)}}
      error -> error
    end
  end

  defp create_memory_chunk(memory, chunk_text, _index) do
    with {:ok, embedding} <- Embeddings.embed_text(chunk_text) do
      %MemoryChunk{}
      |> MemoryChunk.changeset(%{
        text: chunk_text,
        embedding: embedding,
        memory_id: memory.id
      })
      |> Repo.insert()
    end
  end

  defp create_single_chunk(memory, text, embedding) do
    %MemoryChunk{}
    |> MemoryChunk.changeset(%{
      text: text,
      embedding: embedding,
      memory_id: memory.id
    })
    |> Repo.insert()
  end

  defp chunk_text(text, chunk_size, chunk_overlap) when is_binary(text) do
    if String.length(text) <= chunk_size do
      [text]
    else
      do_chunk_text(text, chunk_size, chunk_overlap, [])
    end
  end

  defp do_chunk_text(text, chunk_size, chunk_overlap, acc) do
    if String.length(text) <= chunk_size do
      Enum.reverse([text | acc])
    else
      chunk = String.slice(text, 0, chunk_size)
      remaining = String.slice(text, chunk_size - chunk_overlap, String.length(text))
      do_chunk_text(remaining, chunk_size, chunk_overlap, [chunk | acc])
    end
  end
end
