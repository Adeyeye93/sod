defmodule Sod.Repo do
  use Ecto.Repo,
    otp_app: :sod,
    adapter: Ecto.Adapters.Postgres
end
