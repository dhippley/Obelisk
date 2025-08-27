defmodule Obelisk.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :name, :string, null: false
      add :metadata, :map, null: false, default: "{}"

      timestamps()
    end

    create index(:sessions, [:name])
  end
end
