# lib/smart_bus_web/channels/availability_channel.ex
defmodule SmartBusWeb.AvailabilityChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Driver
  alias SmartBus.DB.Lane

  def join("availability:driver:" <> driver_id, _params, socket) do
    case Driver.get(driver_id) do
      nil -> {:error, %{reason: "Driver not found"}}
      _ ->
        socket = assign(socket, :driver_id, driver_id)
        {:ok, socket}
    end
  end

  def handle_in("go_online", %{"location" => location, "lane" => lane, "available_seats" => seats}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.go_online(driver_id, %{
      location: location,
      lane: lane,
      available_seats: seats
    }) do
      {:ok, driver} ->
        # Broadcast to passengers on this lane
        broadcast_to_lane(lane, "driver_available", %{
          driver_id: driver.id,
          location: driver.current_location,
          available_seats: driver.available_seats,
          vehicle_info: get_vehicle_info(driver_id)
        })

        {:reply, {:ok, %{status: "online", driver: driver}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("go_offline", _payload, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.go_offline(driver_id) do
      {:ok, driver} ->
        # Notify system that driver is offline
        broadcast(socket, "driver_offline", %{
          driver_id: driver.id,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{status: "offline"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("set_route", %{"lane" => lane, "start_point" => start, "end_point" => end_point}, socket) do
    driver_id = socket.assigns.driver_id

    route_data = %{
      lane: lane,
      start_point: start,
      end_point: end_point,
      stops: [],
      schedule: %{}
    }

    case Driver.update_route(driver_id, route_data) do
      {:ok, driver} ->
        {:reply, {:ok, %{route: driver.current_route}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("update_route", %{"stops" => stops, "schedule" => schedule}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.get(driver_id) do
      nil -> {:reply, {:error, %{reason: "Driver not found"}}, socket}
      driver ->
        current_route = driver.current_route || %{}
        updated_route = Map.merge(current_route, %{
          stops: stops,
          schedule: schedule
        })

        Driver.update_route(driver_id, updated_route)
        {:reply, {:ok, %{route: updated_route}}, socket}
    end
  end

  def handle_in("set_stops", %{"stops" => stops}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.get(driver_id) do
      nil -> {:reply, {:error, %{reason: "Driver not found"}}, socket}
      driver ->
        current_route = driver.current_route || %{}
        updated_route = Map.put(current_route, :stops, stops)

        Driver.update_route(driver_id, updated_route)
        {:reply, {:ok, %{stops: stops}}, socket}
    end
  end

  def handle_in("update_location", %{"location" => location}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.update_location(driver_id, location) do
      {:ok, driver} ->
        # Broadcast location update to tracking systems
        broadcast(socket, "location_updated", %{
          driver_id: driver.id,
          location: driver.current_location,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{location: location}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("update_seats", %{"available_seats" => seats}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.get(driver_id) do
      nil -> {:reply, {:error, %{reason: "Driver not found"}}, socket}
      driver ->
        # Update available seats
        updated_driver = %{driver | available_seats: seats}
        {:reply, {:ok, %{available_seats: seats}}, socket}
    end
  end

  def handle_in("get_nearby_passengers", %{"radius" => radius}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.get(driver_id) do
      nil -> {:reply, {:error, %{reason: "Driver not found"}}, socket}
      driver ->
        # Find nearby passengers (simplified)
        nearby_passengers = find_nearby_passengers(driver.current_location, radius)
        {:reply, {:ok, %{passengers: nearby_passengers}}, socket}
    end
  end

  defp get_vehicle_info(driver_id) do
    # Get driver's vehicle info
    %{
      vehicle_id: "vehicle_123",
      model: "Toyota Hiace",
      capacity: 14,
      amenities: ["AC", "WiFi"]
    }
  end

  defp broadcast_to_lane(lane, event, payload) do
    SmartBusWeb.Endpoint.broadcast("lane:#{lane}", event, payload)
  end

  defp find_nearby_passengers(location, radius) do
    # Simplified implementation
    # In production, use spatial queries
    []
  end
end
