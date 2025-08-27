defmodule Obelisk.Repo.Migrations.CreateMemoryChunks do
  use Ecto.Migration

  def change do
    create table(:memory_chunks) do
      add :text, :text, null: false
      add :embedding, :vector, size: 1536
      add :memory_id, references(:memories, on_delete: :delete_all), null: false
    end

    create index(:memory_chunks, [:memory_id])
  end
end
