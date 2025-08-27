defmodule Obelisk.Schemas.MemoryChunkTest do
  use Obelisk.DataCase

  alias Obelisk.Schemas.{Memory, MemoryChunk}

  setup do
    # Sample embedding vector (1536 dimensions)
    embedding = List.duplicate(0.1, 1536)

    {:ok, memory} =
      %Memory{
        kind: :doc,
        text: "Parent memory document",
        embedding: embedding
      }
      |> Repo.insert()

    %{memory: memory, embedding: embedding}
  end

  describe "changeset/2" do
    test "valid changeset with required fields", %{memory: memory, embedding: embedding} do
      attrs = %{
        text: "This is a chunk of the larger memory",
        embedding: embedding,
        memory_id: memory.id
      }

      changeset = MemoryChunk.changeset(%MemoryChunk{}, attrs)

      assert changeset.valid?
      assert changeset.changes.text == "This is a chunk of the larger memory"
      assert changeset.changes.memory_id == memory.id
    end

    test "invalid changeset without text", %{memory: memory, embedding: embedding} do
      attrs = %{
        embedding: embedding,
        memory_id: memory.id
      }

      changeset = MemoryChunk.changeset(%MemoryChunk{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).text
    end

    test "invalid changeset without memory_id", %{embedding: embedding} do
      attrs = %{
        text: "Chunk without parent memory",
        embedding: embedding
      }

      changeset = MemoryChunk.changeset(%MemoryChunk{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).memory_id
    end

    test "valid changeset without embedding (will be set programmatically)", %{memory: memory} do
      attrs = %{
        text: "Chunk without embedding",
        memory_id: memory.id
      }

      changeset = MemoryChunk.changeset(%MemoryChunk{}, attrs)

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :embedding)
    end

    test "updates existing chunk", %{memory: memory, embedding: embedding} do
      chunk = %MemoryChunk{
        text: "Old chunk text",
        embedding: List.duplicate(0.2, 1536),
        memory_id: memory.id
      }

      attrs = %{
        text: "Updated chunk text",
        embedding: embedding
      }

      changeset = MemoryChunk.changeset(chunk, attrs)

      assert changeset.valid?
      assert changeset.changes.text == "Updated chunk text"
      # The embedding gets converted to a Pgvector struct in the changeset
      assert changeset.changes.embedding == Pgvector.new(embedding)
    end
  end
end
