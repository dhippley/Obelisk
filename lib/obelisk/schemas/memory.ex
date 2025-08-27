defmodule Obelisk.Schemas.Memory do
  @moduledoc """
  Schema for storing memories with vector embeddings for semantic search.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @kinds [:note, :fact, :doc, :code, :event]

  schema "memories" do
    field :kind, Ecto.Enum, values: @kinds
    field :text, :string
    field :metadata, :map, default: %{}
    field :embedding, Pgvector.Ecto.Vector
    belongs_to :session, Obelisk.Schemas.Session  # NULL => global memory
    has_many :memory_chunks, Obelisk.Schemas.MemoryChunk
    timestamps(updated_at: false)
  end

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [:kind, :text, :metadata, :embedding, :session_id])
    |> validate_required([:kind, :text])
    |> validate_inclusion(:kind, @kinds)
  end
end
