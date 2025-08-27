defmodule Obelisk.Repo.Migrations.AddVectorIndices do
  use Ecto.Migration

  def up do
    # Create vector index on memory_chunks for fast similarity search
    # Using ivfflat index with lists=100 as a good starting point
    execute(
      "CREATE INDEX ON memory_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    )

    # Optional: also create index on memories table embeddings
    execute(
      "CREATE INDEX ON memories USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
    )
  end

  def down do
    execute("DROP INDEX IF EXISTS memory_chunks_embedding_idx")
    execute("DROP INDEX IF EXISTS memories_embedding_idx")
  end
end
