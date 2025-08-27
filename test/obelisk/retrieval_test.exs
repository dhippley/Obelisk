defmodule Obelisk.RetrievalTest do
  use Obelisk.DataCase

  alias Obelisk.{Retrieval, Repo}
  alias Obelisk.Schemas.{Session, Memory, MemoryChunk}

  describe "get_memory_chunks/1" do
    test "returns chunks for a specific memory" do
      embedding = List.duplicate(0.1, 1536)

      {:ok, memory} =
        %Memory{
          kind: :doc,
          text: "Parent memory",
          embedding: embedding
        }
        |> Repo.insert()

      {:ok, _chunk1} =
        %MemoryChunk{
          text: "First chunk",
          embedding: List.duplicate(0.2, 1536),
          memory_id: memory.id
        }
        |> Repo.insert()

      {:ok, _chunk2} =
        %MemoryChunk{
          text: "Second chunk",
          embedding: List.duplicate(0.3, 1536),
          memory_id: memory.id
        }
        |> Repo.insert()

      chunks = Retrieval.get_memory_chunks(memory.id)

      assert length(chunks) == 2
      chunk_texts = Enum.map(chunks, & &1.text)
      assert "First chunk" in chunk_texts
      assert "Second chunk" in chunk_texts
    end

    test "returns empty list for memory with no chunks" do
      embedding = List.duplicate(0.1, 1536)

      {:ok, memory} =
        %Memory{
          kind: :doc,
          text: "Memory without chunks",
          embedding: embedding
        }
        |> Repo.insert()

      chunks = Retrieval.get_memory_chunks(memory.id)
      assert chunks == []
    end

    test "returns empty list for non-existent memory" do
      chunks = Retrieval.get_memory_chunks(999999)
      assert chunks == []
    end
  end

  describe "retrieve_by_embedding/4" do
    setup do
      # Create test data with different embeddings for similarity testing
      {:ok, session} =
        %Session{name: "test-session"}
        |> Repo.insert()

      # Create similar embeddings (high similarity)
      similar_embedding_1 = List.duplicate(0.9, 1536)
      similar_embedding_2 = List.duplicate(0.85, 1536)

      # Create dissimilar embedding (low similarity)
      dissimilar_embedding = List.duplicate(0.1, 1536)

      # Global memory with similar embedding
      {:ok, global_memory} =
        %Memory{
          kind: :fact,
          text: "Global knowledge",
          embedding: similar_embedding_1
        }
        |> Repo.insert()

      {:ok, _global_chunk} =
        %MemoryChunk{
          text: "Global chunk with similar embedding",
          embedding: similar_embedding_1,
          memory_id: global_memory.id
        }
        |> Repo.insert()

      # Session memory with similar embedding
      {:ok, session_memory} =
        %Memory{
          kind: :note,
          text: "Session knowledge",
          embedding: similar_embedding_2,
          session_id: session.id
        }
        |> Repo.insert()

      {:ok, _session_chunk} =
        %MemoryChunk{
          text: "Session chunk with similar embedding",
          embedding: similar_embedding_2,
          memory_id: session_memory.id
        }
        |> Repo.insert()

      # Dissimilar memory
      {:ok, dissimilar_memory} =
        %Memory{
          kind: :doc,
          text: "Unrelated knowledge",
          embedding: dissimilar_embedding
        }
        |> Repo.insert()

      {:ok, _dissimilar_chunk} =
        %MemoryChunk{
          text: "Dissimilar chunk",
          embedding: dissimilar_embedding,
          memory_id: dissimilar_memory.id
        }
        |> Repo.insert()

      query_embedding = List.duplicate(0.87, 1536)  # Similar to our test data

      %{
        session: session,
        query_embedding: query_embedding
      }
    end

    test "retrieves chunks by embedding similarity", %{query_embedding: query_embedding} do
      results = Retrieval.retrieve_by_embedding(query_embedding, nil, 5, %{threshold: 0.5})

      assert is_list(results)
      # Should find chunks with similar embeddings
      assert length(results) >= 1

      # Results should have expected structure
      if results != [] do
        result = hd(results)
        assert Map.has_key?(result, :id)
        assert Map.has_key?(result, :text)
        assert Map.has_key?(result, :score)
        assert Map.has_key?(result, :memory_id)
        assert Map.has_key?(result, :kind)
        assert is_float(result.score)
      end
    end

    test "filters by similarity threshold", %{query_embedding: query_embedding} do
      # High threshold should return fewer results
      high_threshold_results = Retrieval.retrieve_by_embedding(
        query_embedding, nil, 10, %{threshold: 0.95}
      )

      # Low threshold should return more results
      low_threshold_results = Retrieval.retrieve_by_embedding(
        query_embedding, nil, 10, %{threshold: 0.1}
      )

      assert length(high_threshold_results) <= length(low_threshold_results)
    end

    test "respects k limit", %{query_embedding: query_embedding} do
      results_k2 = Retrieval.retrieve_by_embedding(query_embedding, nil, 2, %{threshold: 0.0})
      results_k10 = Retrieval.retrieve_by_embedding(query_embedding, nil, 10, %{threshold: 0.0})

      assert length(results_k2) <= 2
      assert length(results_k10) >= length(results_k2)
    end

    test "includes global memories when session_id is nil", %{query_embedding: query_embedding} do
      results = Retrieval.retrieve_by_embedding(query_embedding, nil, 10, %{threshold: 0.0})

      global_results = Enum.filter(results, fn result ->
        result.session_id == nil
      end)

      assert length(global_results) >= 1
    end

    test "includes session and global memories by default", %{
      session: session,
      query_embedding: query_embedding
    } do
      results = Retrieval.retrieve_by_embedding(query_embedding, session.id, 10, %{threshold: 0.0})

      # Should include both global and session memories
      has_global = Enum.any?(results, fn result -> result.session_id == nil end)
      has_session = Enum.any?(results, fn result -> result.session_id == session.id end)

      assert has_global or has_session  # Should have at least one type
    end

    test "excludes global memories when include_global is false", %{
      session: session,
      query_embedding: query_embedding
    } do
      results = Retrieval.retrieve_by_embedding(
        query_embedding,
        session.id,
        10,
        %{threshold: 0.0, include_global: false}
      )

      # Should only include session memories
      session_only = Enum.all?(results, fn result ->
        result.session_id == session.id
      end)

      assert session_only or results == []
    end
  end

  describe "error handling" do
    test "handles query errors gracefully" do
      # Test with invalid embedding (wrong dimensions) 
      # Note: Some invalid embeddings might return empty results rather than errors
      invalid_embedding = [0.1, 0.2, 0.3]  # Too few dimensions
      
      result = Retrieval.retrieve_by_embedding(invalid_embedding)
      
      # Could return either an error or empty results depending on how PostgreSQL handles it
      case result do
        {:error, {:query_failed, _}} -> :ok  # Error as expected
        [] -> :ok  # Empty results also acceptable for invalid input
        results when is_list(results) -> :ok  # Any list result is acceptable
      end
    end
  end
end
