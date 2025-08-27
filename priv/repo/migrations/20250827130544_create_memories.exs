defmodule Obelisk.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories) do
      add :kind, :string, null: false
      add :text, :text, null: false
      add :metadata, :map, null: false, default: "{}"
      add :embedding, :vector, size: 1536
      add :session_id, references(:sessions, on_delete: :nilify_all)

      add :inserted_at, :utc_datetime_usec, null: false
    end

    create index(:memories, [:session_id])
    create index(:memories, [:kind])
    create index(:memories, [:inserted_at])
  end
end
