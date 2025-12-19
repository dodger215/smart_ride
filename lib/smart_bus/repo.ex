defmodule SmartBus.Repo do
  use Ecto.Repo,
    otp_app: :smart_bus,
    adapter: Ecto.Adapters.Postgres
end
