defmodule Obelisk.Schemas.MemoryTest do
  use Obelisk.DataCase

  alias Obelisk.Schemas.{Memory, Session}

  setup do
    {:ok, session} =
      %Session{name: "test-session"}
      |> Repo.insert()

    # Sample embedding vector (1536 dimensions)
    embedding = List.duplicate(0.1, 1536)

    %{session: session, embedding: embedding}
  end

  describe "changeset/2" do
    test "valid changeset with required fields", %{embedding: embedding} do
      attrs = %{
        kind: :note,
        text: "This is a test memory",
        embedding: embedding
      }

      changeset = Memory.changeset(%Memory{}, attrs)

      assert changeset.valid?
      assert changeset.changes.kind == :note
      assert changeset.changes.text == "This is a test memory"
      # metadata has a default value, so it won't be in changes unless explicitly set
      refute Map.has_key?(changeset.changes, :metadata)
    end

    test "valid changeset with session", %{session: session, embedding: embedding} do
      attrs = %{
        kind: :fact,
        text: "Session-scoped memory",
        embedding: embedding,
        session_id: session.id,
        metadata: %{source: "chat", importance: "high"}
      }

      changeset = Memory.changeset(%Memory{}, attrs)

      assert changeset.valid?
      assert changeset.changes.session_id == session.id
      assert changeset.changes.metadata == %{source: "chat", importance: "high"}
    end

    test "valid changeset for each kind", %{embedding: embedding} do
      kinds = [:note, :fact, :doc, :code, :event]

      for kind <- kinds do
        attrs = %{
          kind: kind,
          text: "Test memory for #{kind}",
          embedding: embedding
        }

        changeset = Memory.changeset(%Memory{}, attrs)

        assert changeset.valid?, "Kind #{kind} should be valid"
        assert changeset.changes.kind == kind
      end
    end

    test "invalid changeset without kind", %{embedding: embedding} do
      attrs = %{
        text: "Memory without kind",
        embedding: embedding
      }

      changeset = Memory.changeset(%Memory{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).kind
    end

    test "invalid changeset without text", %{embedding: embedding} do
      attrs = %{
        kind: :note,
        embedding: embedding
      }

      changeset = Memory.changeset(%Memory{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).text
    end

    test "invalid changeset with invalid kind", %{embedding: embedding} do
      attrs = %{
        kind: :invalid_kind,
        text: "Memory with invalid kind",
        embedding: embedding
      }

      changeset = Memory.changeset(%Memory{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).kind
    end

    test "valid changeset without embedding (will be set programmatically)" do
      attrs = %{
        kind: :note,
        text: "Memory without embedding"
      }

      changeset = Memory.changeset(%Memory{}, attrs)

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :embedding)
    end

    test "global memory without session_id", %{embedding: embedding} do
      attrs = %{
        kind: :doc,
        text: "Global memory accessible to all sessions",
        embedding: embedding
      }

      changeset = Memory.changeset(%Memory{}, attrs)

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :session_id)
    end
  end
end
