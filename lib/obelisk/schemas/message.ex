defmodule Obelisk.Schemas.Message do
  @moduledoc """
  Schema for chat messages with role-based content and tool support.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @roles [:system, :user, :assistant, :tool]

  schema "messages" do
    field :role, Ecto.Enum, values: @roles
    field :content, :map  # store text, tool outputs, deltas, etc.
    field :tool_name, :string
    belongs_to :session, Obelisk.Schemas.Session
    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :tool_name, :session_id])
    |> validate_required([:role, :content])
    |> validate_inclusion(:role, @roles)
  end
end
