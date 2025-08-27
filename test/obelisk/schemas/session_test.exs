defmodule Obelisk.Schemas.SessionTest do
  use Obelisk.DataCase

  alias Obelisk.Schemas.Session

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{name: "test-session"}
      changeset = Session.changeset(%Session{}, attrs)

      assert changeset.valid?
      assert changeset.changes.name == "test-session"
      # metadata has a default value, so it won't be in changes unless explicitly set
      refute Map.has_key?(changeset.changes, :metadata)
    end

    test "valid changeset with metadata" do
      attrs = %{name: "test-session", metadata: %{user_id: 123, source: "cli"}}
      changeset = Session.changeset(%Session{}, attrs)

      assert changeset.valid?
      assert changeset.changes.metadata == %{user_id: 123, source: "cli"}
    end

    test "invalid changeset without name" do
      attrs = %{metadata: %{test: true}}
      changeset = Session.changeset(%Session{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid changeset with empty name" do
      attrs = %{name: ""}
      changeset = Session.changeset(%Session{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "updates existing session" do
      session = %Session{name: "old-name", metadata: %{old: true}}
      attrs = %{name: "new-name", metadata: %{new: true}}
      changeset = Session.changeset(session, attrs)

      assert changeset.valid?
      assert changeset.changes.name == "new-name"
      assert changeset.changes.metadata == %{new: true}
    end
  end
end
