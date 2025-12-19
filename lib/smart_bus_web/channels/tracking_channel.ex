defmodule SmartBusWeb.TrackingChannel do
  use Phoenix.Channel
  alias SmartBus.DB.GPSLog
  alias SmartBus.DB.Driver
  alias SmartBus.DB.Trip

  def join("tracking:vehicle:" <> vehicle_id, _params, socket) do
    socket = assign(socket, :vehicle_id, vehicle_id)
    {:ok, socket}
  end

  def join("tracking:trip:" <> trip_id, _params, socket) do
    case Trip.get(trip_id) do
      nil -> {:error, %{reason: "Trip not found"}}
      _ ->
        socket = assign(socket, :trip_id, trip_id)
        {:ok, socket}
    end
  end

  def join("tracking:driver:" <> driver_id, _params, socket) do
    socket = assign(socket, :driver_id, driver_id)
    {:ok, socket}
  end

  def handle_in("update_location", %{"latitude" => lat, "longitude" => lng} = payload, socket) do
    driver_id = socket.assigns.driver_id

    # Create GPS log
    gps_data = %{
      driver_id: driver_id,
      latitude: lat,
      longitude: lng,
      speed: payload["speed"] || 0.0,
      heading: payload["heading"] || 0.0,
      accuracy: payload["accuracy"] || 10.0,
      battery_level: payload["battery_level"] || 100
    }

    {:ok, _log} = GPSLog.create(gps_data)

    # Update driver's current location
    Driver.update_location(driver_id, {lat, lng})

    # Broadcast to trip channels
    broadcast_to_active_trips(driver_id, {lat, lng}, payload)

    {:reply, {:ok, %{timestamp: DateTime.utc_now()}}, socket}
  end

  def handle_in("get_eta", %{"destination" => destination}, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        # Get driver's current location
        driver_location = get_driver_location(trip.driver_id)

        if driver_location do
          eta = calculate_eta(driver_location, destination)
          {:reply, {:ok, %{eta_minutes: eta, destination: destination}}, socket}
        else
          {:reply, {:ok, %{eta_minutes: 5, message: "Using default ETA"}}, socket}
        end
    end
  end

  def handle_in("track_bus", %{"trip_id" => trip_id}, socket) do
    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        # Get recent locations
        vehicle_id = get_vehicle_id(trip.driver_id)
        locations = GPSLog.get_recent(vehicle_id)

        # Get current driver location
        driver_location = get_driver_location(trip.driver_id)

        {:reply, {:ok, %{
          trip: trip,
          current_location: driver_location,
          recent_locations: locations,
          route: get_route_info(trip)
        }}, socket}
    end
  end

  def handle_in("geofence_alert", %{"geofence_id" => geofence_id, "event" => event}, socket) do
    driver_id = socket.assigns.driver_id

    # Handle geofence events (entered/exited)
    broadcast(socket, "geofence_event", %{
      driver_id: driver_id,
      geofence_id: geofence_id,
      event: event,
      timestamp: DateTime.utc_now()
    })

    {:reply, {:ok, %{message: "Geofence alert processed"}}, socket}
  end

  def handle_in("get_navigation", %{"destination" => destination}, socket) do
    driver_id = socket.assigns.driver_id

    # Get current location
    driver_location = get_driver_location(driver_id)

    if driver_location do
      route = calculate_route(driver_location, destination)
      {:reply, {:ok, %{route: route, distance: route.distance, duration: route.duration}}, socket}
    else
      {:reply, {:error, %{reason: "Location not available"}}, socket}
    end
  end

  def handle_in("optimize_route", %{"stops" => stops}, socket) do
    # Optimize route for multiple stops
    optimized_route = optimize_stops_order(stops)

    {:reply, {:ok, %{
      optimized_route: optimized_route,
      total_distance: calculate_total_distance(optimized_route)
    }}, socket}
  end

  defp broadcast_to_active_trips(driver_id, location, payload) do
    # Get all active trips for this driver
    trips = Trip.get_active_driver_trips(driver_id)

    Enum.each(trips, fn trip ->
      SmartBusWeb.Endpoint.broadcast("tracking:trip:#{trip.id}", "location_update", %{
        latitude: elem(location, 0),
        longitude: elem(location, 1),
        speed: payload["speed"] || 0.0,
        heading: payload["heading"] || 0.0,
        timestamp: DateTime.utc_now(),
        eta_to_dropoff: calculate_eta(location, trip.dropoff_location)
      })
    end)
  end

  defp get_driver_location(driver_id) do
    case Driver.get(driver_id) do
      nil -> nil
      driver -> driver.current_location
    end
  end

  defp get_vehicle_id(driver_id) do
    # Get driver's vehicle ID
    "vehicle_#{driver_id}"
  end

  defp get_route_info(trip) do
    %{
      pickup: trip.pickup_location,
      dropoff: trip.dropoff_location,
      waypoints: []
    }
  end

  defp calculate_eta(from, to) do
    # Simplified ETA calculation
    10 # minutes
  end

  defp calculate_route(from, to) do
    %{
      points: [from, to],
      distance: 5.2, # km
      duration: 15, # minutes
      polyline: "encoded_polyline"
    }
  end

  defp optimize_stops_order(stops) do
    # Simplified optimization (nearest neighbor)
    stops
  end

  defp calculate_total_distance(route) do
    0.0
  end
end
