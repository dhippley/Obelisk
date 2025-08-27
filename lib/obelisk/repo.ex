defmodule Obelisk.Repo do
  use Ecto.Repo,
    otp_app: :obelisk,
    adapter: Ecto.Adapters.Postgres
end
