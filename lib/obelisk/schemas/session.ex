defmodule Obelisk.Schemas.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :name, :string
    field :metadata, :map, default: %{}
    has_many :messages, Obelisk.Schemas.Message
    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:name, :metadata])
    |> validate_required([:name])
  end
end
