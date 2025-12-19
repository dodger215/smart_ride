# lib/smart_bus/application.ex
defmodule SmartBus.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      SmartBusWeb.Telemetry,
      # Start the custom database
      {SmartBus.DB, []},
      # Start the PubSub system
      {Phoenix.PubSub, name: SmartBus.PubSub},
      # Start Finch
      {Finch, name: SmartBus.Finch},
      # Start the Endpoint (http/https)
      SmartBusWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: SmartBus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    SmartBusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
