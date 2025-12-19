ExUnit.start()

# Skip database initialization for channel tests
try do
  Ecto.Adapters.SQL.Sandbox.mode(SmartBus.Repo, :manual)
rescue
  _ ->
    # Database not available, tests will use in-memory database
    :ok
end
