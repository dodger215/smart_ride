defmodule SmartBusWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "auth:*", SmartBusWeb.AuthChannel
  channel "passenger:*", SmartBusWeb.PassengerChannel
  channel "driver:*", SmartBusWeb.DriverChannel
  channel "vehicle:*", SmartBusWeb.VehicleChannel
  channel "availability:*", SmartBusWeb.AvailabilityChannel
  channel "ride_request:*", SmartBusWeb.RideRequestChannel
  channel "ride_management:*", SmartBusWeb.RideManagementChannel
  channel "seat_management:*", SmartBusWeb.SeatManagementChannel
  channel "tracking:*", SmartBusWeb.TrackingChannel
  channel "payment:*", SmartBusWeb.PaymentChannel
  channel "notification:*", SmartBusWeb.NotificationChannel
  channel "admin:*", SmartBusWeb.AdminChannel
  channel "gps:*", SmartBusWeb.GPSChannel
  channel "review:*", SmartBusWeb.ReviewChannel
  channel "reports:*", SmartBusWeb.ReportsChannel
  channel "integration:*", SmartBusWeb.IntegrationChannel
  channel "dynamic_pricing:*", SmartBusWeb.DynamicPricingChannel
  channel "route_optimization:*", SmartBusWeb.RouteOptimizationChannel
  channel "offline_operations:*", SmartBusWeb.OfflineOperationsChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  # the current user id. After verification, you can
  # put default assigns into the socket that will be set
  # for all channels, ie:
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     SmartBusWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
