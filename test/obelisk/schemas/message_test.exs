defmodule Obelisk.Schemas.MessageTest do
  use Obelisk.DataCase

  alias Obelisk.Schemas.{Session, Message}

  setup do
    {:ok, session} =
      %Session{name: "test-session"}
      |> Repo.insert()

    %{session: session}
  end

  describe "changeset/2" do
    test "valid changeset with user message", %{session: session} do
      attrs = %{
        role: :user,
        content: %{text: "Hello, world!"},
        session_id: session.id
      }
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert changeset.changes.role == :user
      assert changeset.changes.content == %{text: "Hello, world!"}
    end

    test "valid changeset with tool message", %{session: session} do
      attrs = %{
        role: :tool,
        content: %{result: "File created successfully"},
        tool_name: "create_file",
        session_id: session.id
      }
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert changeset.changes.role == :tool
      assert changeset.changes.tool_name == "create_file"
    end

    test "valid changeset with assistant message", %{session: session} do
      attrs = %{
        role: :assistant,
        content: %{text: "I can help you with that", tokens: 1024},
        session_id: session.id
      }
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert changeset.changes.role == :assistant
    end

    test "invalid changeset without role", %{session: session} do
      attrs = %{
        content: %{text: "Hello"},
        session_id: session.id
      }
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "invalid changeset without content", %{session: session} do
      attrs = %{
        role: :user,
        session_id: session.id
      }
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "invalid changeset with invalid role", %{session: session} do
      attrs = %{
        role: :invalid_role,
        content: %{text: "Hello"},
        session_id: session.id
      }
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "valid changeset for each role type", %{session: session} do
      roles = [:system, :user, :assistant, :tool]

      for role <- roles do
        attrs = %{
          role: role,
          content: %{text: "Test message for #{role}"},
          session_id: session.id
        }
        changeset = Message.changeset(%Message{}, attrs)

        assert changeset.valid?, "Role #{role} should be valid"
        assert changeset.changes.role == role
      end
    end
  end
end
