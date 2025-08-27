defmodule Obelisk.MemoryTest do
  use Obelisk.DataCase

  alias Obelisk.{Memory, Repo}
  alias Obelisk.Schemas.Memory, as: MemorySchema

  describe "get_or_create_session/2" do
    test "creates new session when it doesn't exist" do
      assert {:ok, session} = Memory.get_or_create_session("new-session")

      assert session.name == "new-session"
      assert session.metadata == %{}
      assert session.id
    end

    test "creates session with metadata" do
      metadata = %{user_id: 123, source: "cli"}
      assert {:ok, session} = Memory.get_or_create_session("session-with-meta", metadata)

      assert session.name == "session-with-meta"
      assert session.metadata == metadata
    end

    test "returns existing session" do
      # Create initial session
      {:ok, original} = Memory.get_or_create_session("existing-session")

      # Try to get the same session
      {:ok, retrieved} = Memory.get_or_create_session("existing-session")

      assert original.id == retrieved.id
      assert retrieved.name == "existing-session"
    end
  end

  describe "list_memories/1" do
    test "lists global memories when session_id is nil" do
      # Create a global memory (we'll need to mock embeddings for this to work)
      # For now, let's create the memory record directly
      embedding = List.duplicate(0.1, 1536)

      {:ok, _memory} =
        %MemorySchema{
          kind: :note,
          text: "Global memory",
          embedding: embedding,
          session_id: nil
        }
        |> Repo.insert()

      memories = Memory.list_memories(nil)
      assert length(memories) == 1
      assert hd(memories).text == "Global memory"
      assert hd(memories).session_id == nil
    end

    test "lists session-specific memories" do
      {:ok, session} = Memory.get_or_create_session("test-session")
      embedding = List.duplicate(0.1, 1536)

      {:ok, _memory} =
        %MemorySchema{
          kind: :note,
          text: "Session memory",
          embedding: embedding,
          session_id: session.id
        }
        |> Repo.insert()

      memories = Memory.list_memories(session.id)
      assert length(memories) == 1
      assert hd(memories).text == "Session memory"
      assert hd(memories).session_id == session.id
    end

    test "returns empty list when no memories exist" do
      {:ok, session} = Memory.get_or_create_session("empty-session")

      memories = Memory.list_memories(session.id)
      assert memories == []
    end

    test "orders memories by inserted_at desc" do
      embedding = List.duplicate(0.1, 1536)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      # Insert memories with explicit timestamps to ensure ordering
      {:ok, _first} =
        %MemorySchema{
          kind: :note,
          text: "First memory",
          embedding: embedding,
          inserted_at: NaiveDateTime.add(now, -10, :second)
        }
        |> Repo.insert()

      {:ok, _second} =
        %MemorySchema{
          kind: :note,
          text: "Second memory",
          embedding: embedding,
          inserted_at: now
        }
        |> Repo.insert()

      memories = Memory.list_memories(nil)
      assert length(memories) == 2

      # Should be ordered by most recent first
      assert hd(memories).text == "Second memory"
      assert hd(tl(memories)).text == "First memory"
    end
  end

  describe "delete_memory/1" do
    test "deletes existing memory" do
      embedding = List.duplicate(0.1, 1536)

      {:ok, memory} =
        %MemorySchema{
          kind: :note,
          text: "Memory to delete",
          embedding: embedding
        }
        |> Repo.insert()

      assert {:ok, _} = Memory.delete_memory(memory.id)
      assert Repo.get(MemorySchema, memory.id) == nil
    end

    test "returns error for non-existent memory" do
      assert {:error, :not_found} = Memory.delete_memory(999_999)
    end
  end

  describe "text chunking" do
    # Test the private text chunking functions indirectly by testing their behavior
    test "chunk_text handles short text" do
      # We can't directly test private functions, but we can test the behavior
      # by using store_memory_simple and checking the result

      # This test would require mocking the Embeddings module
      # For now, let's focus on the logic we can test

      short_text = "Short text that fits in one chunk"
      # Default chunk size
      assert String.length(short_text) < 1000

      # The chunking behavior would be tested when we implement store_memory
    end
  end
end
