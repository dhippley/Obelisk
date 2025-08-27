defmodule Obelisk.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :role, :string, null: false
      add :content, :map, null: false
      add :tool_name, :string
      add :session_id, references(:sessions, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:messages, [:session_id])
    create index(:messages, [:role])
    create index(:messages, [:tool_name])
    # GIN index for JSONB content for fast tool result search
    create index(:messages, [:content], using: "GIN")
  end
end
