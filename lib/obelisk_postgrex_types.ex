Postgrex.Types.define(
  ObeliskPostgrexTypes,
  Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(),
  []
)
