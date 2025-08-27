defmodule Obelisk.Schemas.MemoryChunk do
  @moduledoc """
  Schema for chunked memory pieces with vector embeddings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "memory_chunks" do
    field :text, :string
    field :embedding, Pgvector.Ecto.Vector
    belongs_to :memory, Obelisk.Schemas.Memory
  end

  def changeset(memory_chunk, attrs) do
    memory_chunk
    |> cast(attrs, [:text, :embedding, :memory_id])
    |> validate_required([:text, :memory_id])
  end
end
