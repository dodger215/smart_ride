defmodule SmartBusWeb.RideRequestChannel do
  use Phoenix.Channel
  alias SmartBus.DB.RideRequest
  alias SmartBus.DB.Driver
  alias SmartBus.DB.Trip
  alias SmartBus.DB.Lane

  def join("ride_request:passenger:" <> passenger_id, _params, socket) do
    socket = assign(socket, :passenger_id, passenger_id)
    {:ok, socket}
  end

  def join("ride_request:driver:" <> driver_id, _params, socket) do
    socket = assign(socket, :driver_id, driver_id)
    {:ok, socket}
  end

  def join("ride_request:lane:" <> lane, _params, socket) do
    socket = assign(socket, :lane, lane)
    {:ok, socket}
  end

  def handle_in("create_request", payload, socket) do
    passenger_id = socket.assigns.passenger_id

    request_data = %{
      passenger_id: passenger_id,
      lane: payload["lane"],
      pickup_location: payload["pickup_location"],
      dropoff_location: payload["dropoff_location"],
      seats_requested: payload["seats_requested"] || 1,
      estimated_fare: payload["estimated_fare"],
      estimated_distance: payload["estimated_distance"],
      estimated_time: payload["estimated_time"]
    }

    case RideRequest.create(request_data) do
      {:ok, request} ->
        # Start matching process
        spawn(fn -> match_request(request) end)

        # Notify passenger
        broadcast(socket, "request_created", %{
          request_id: request.id,
          status: "searching",
          estimated_wait_time: 180 # 3 minutes
        })

        {:reply, {:ok, %{
          request_id: request.id,
          status: "searching",
          message: "Looking for available buses"
        }}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("cancel_request", %{"request_id" => request_id, "reason" => reason}, socket) do
    case RideRequest.get(request_id) do
      nil -> {:reply, {:error, %{reason: "Request not found"}}, socket}
      request ->
        # Update request status
        RideRequest.update_status(request_id, :cancelled)

        # If already matched, notify driver
        if request.matched_driver_id do
          broadcast_to_driver(request.matched_driver_id, "request_cancelled", %{
            request_id: request_id,
            passenger_id: request.passenger_id,
            reason: reason
          })
        end

        {:reply, {:ok, %{message: "Ride request cancelled"}}, socket}
    end
  end

  def handle_in("view_available_buses", %{"lane" => lane, "location" => location}, socket) do
    # Find online drivers on this lane
    drivers = Driver.find_online_on_lane(lane)
    |> Enum.map(fn driver ->
      %{
        driver_id: driver.id,
        vehicle_info: get_vehicle_info(driver.id),
        eta: calculate_eta(driver.current_location, location),
        available_seats: driver.available_seats,
        rating: driver.rating
      }
    end)

    {:reply, {:ok, %{buses: drivers, count: length(drivers)}}, socket}
  end

  def handle_in("match_passenger", %{"request_id" => request_id}, socket) do
    # Manual matching (admin or system)
    match_request(RideRequest.get(request_id))
    {:reply, {:ok, %{message: "Matching process started"}}, socket}
  end

  def handle_in("request_timeout", %{"request_id" => request_id}, socket) do
    case RideRequest.get(request_id) do
      nil -> {:ok, socket}
      request ->
        if request.status == :pending do
          RideRequest.update_status(request_id, :timeout)

          # Notify passenger
          broadcast_to_passenger(request.passenger_id, "request_timeout", %{
            request_id: request_id,
            message: "No drivers available at this time"
          })
        end
        {:reply, {:ok, %{message: "Request timeout processed"}}, socket}
    end
  end

  def handle_in("accept_ride", %{"request_id" => request_id}, socket) do
    driver_id = socket.assigns.driver_id

    case RideRequest.get(request_id) do
      nil -> {:reply, {:error, %{reason: "Request not found"}}, socket}
      request ->
        # Create trip from request
        trip_data = %{
          passenger_id: request.passenger_id,
          driver_id: driver_id,
          pickup_location: request.pickup_location,
          dropoff_location: request.dropoff_location,
          seats_booked: request.seats_requested,
          estimated_distance: request.estimated_distance,
          estimated_time_minutes: request.estimated_time,
          fare_amount: request.estimated_fare
        }

        case Trip.create(trip_data) do
          {:ok, trip} ->
            # Update request status
            RideRequest.match(request_id, driver_id, nil)

            # Notify passenger
            broadcast_to_passenger(request.passenger_id, "driver_assigned", %{
              trip_id: trip.id,
              driver_id: driver_id,
              vehicle_info: get_vehicle_info(driver_id),
              eta: calculate_eta(nil, request.pickup_location)
            })

            {:reply, {:ok, %{
              trip_id: trip.id,
              passenger_id: request.passenger_id,
              pickup_location: request.pickup_location
            }}, socket}
          {:error, reason} ->
            {:reply, {:error, %{reason: reason}}, socket}
        end
    end
  end

  def handle_in("reject_ride", %{"request_id" => request_id, "reason" => reason}, socket) do
    case RideRequest.get(request_id) do
      nil -> {:reply, {:error, %{reason: "Request not found"}}, socket}
      request ->
        # Update request status
        RideRequest.update_status(request_id, :rejected)

        # Find another driver or notify passenger
        spawn(fn -> match_request(request) end)

        {:reply, {:ok, %{message: "Ride rejected"}}, socket}
    end
  end

  defp match_request(request) do
    # Find suitable drivers
    suitable_drivers = Driver.find_online_on_lane(request.lane, request.seats_requested)

    case suitable_drivers do
      [] ->
        # No drivers available
        RideRequest.update_status(request.id, :timeout)
        broadcast_to_passenger(request.passenger_id, "no_drivers", %{
          request_id: request.id
        })

      drivers ->
        # Sort by proximity to pickup
        nearest_driver = Enum.min_by(drivers, fn driver ->
          calculate_distance(driver.current_location, request.pickup_location)
        end)

        # Send request to driver
        broadcast_to_driver(nearest_driver.id, "ride_request", %{
          request_id: request.id,
          passenger_id: request.passenger_id,
          pickup_location: request.pickup_location,
          dropoff_location: request.dropoff_location,
          seats_requested: request.seats_requested,
          estimated_fare: request.estimated_fare,
          eta: calculate_eta(nearest_driver.current_location, request.pickup_location)
        })

        # Set timeout for driver response
        Process.send_after(self(), {:request_timeout, request.id}, 30_000)
    end
  end

  defp calculate_distance(loc1, loc2) do
    {lat1, lng1} = loc1
    {lat2, lng2} = loc2
    :math.sqrt(:math.pow(lat2 - lat1, 2) + :math.pow(lng2 - lng1, 2))
  end

  defp calculate_eta(driver_loc, passenger_loc) do
    # Simplified ETA calculation
    if driver_loc && passenger_loc do
      distance = calculate_distance(driver_loc, passenger_loc)
      # Assume average speed of 30 km/h
      time_hours = distance * 111.32 / 30  # 1 degree ≈ 111.32 km
      round(time_hours * 60)  # Convert to minutes
    else
      5  # Default 5 minutes
    end
  end

  defp get_vehicle_info(driver_id) do
    %{
      model: "Bus",
      capacity: 14,
      amenities: []
    }
  end

  defp broadcast_to_passenger(passenger_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("passenger:#{passenger_id}", event, payload)
  end

  defp broadcast_to_driver(driver_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("driver:#{driver_id}", event, payload)
  end
end
