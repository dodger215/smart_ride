# lib/smart_bus_web/channels/ride_management_channel.ex
defmodule SmartBusWeb.RideManagementChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Trip
  alias SmartBus.DB.Driver
  alias SmartBus.DB.Seat

  def join("ride_management:trip:" <> trip_id, _params, socket) do
    case Trip.get(trip_id) do
      nil -> {:error, %{reason: "Trip not found"}}
      _ ->
        socket = assign(socket, :trip_id, trip_id)
        {:ok, socket}
    end
  end

  def join("ride_management:driver:" <> driver_id, _params, socket) do
    socket = assign(socket, :driver_id, driver_id)
    {:ok, socket}
  end

  def handle_in("accept_request", %{"request_id" => request_id}, socket) do
    driver_id = socket.assigns.driver_id

    # This is handled in ride_request_channel
    {:reply, {:ok, %{message: "Request accepted"}}, socket}
  end

  def handle_in("reject_request", %{"request_id" => request_id, "reason" => reason}, socket) do
    driver_id = socket.assigns.driver_id

    # Notify ride request channel
    SmartBusWeb.Endpoint.broadcast("ride_request:driver:#{driver_id}", "request_rejected", %{
      request_id: request_id,
      reason: reason
    })

    {:reply, {:ok, %{message: "Request rejected"}}, socket}
  end

  def handle_in("start_trip", _payload, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.update_status(trip_id, :in_progress) do
      {:ok, trip} ->
        # Notify passenger
        broadcast_to_passenger(trip.passenger_id, "trip_started", %{
          trip_id: trip.id,
          start_time: trip.actual_pickup_time,
          driver_location: get_driver_location(trip.driver_id)
        })

        {:reply, {:ok, %{trip: trip, message: "Trip started"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("end_trip", _payload, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.update_status(trip_id, :completed) do
      {:ok, trip} ->
        # Release seats
        release_seats(trip)

        # Update driver availability
        Driver.release_seats(trip.driver_id, trip.seats_booked)

        # Notify passenger
        broadcast_to_passenger(trip.passenger_id, "trip_completed", %{
          trip_id: trip.id,
          end_time: trip.actual_dropoff_time,
          fare_amount: trip.fare_amount,
          payment_status: trip.payment_status
        })

        {:reply, {:ok, %{trip: trip, message: "Trip completed"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("cancel_trip", %{"reason" => reason, "cancelled_by" => cancelled_by}, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.cancel(trip_id, reason, String.to_atom(cancelled_by)) do
      {:ok, trip} ->
        # Release seats
        release_seats(trip)

        # Update driver availability
        Driver.release_seats(trip.driver_id, trip.seats_booked)

        # Notify both parties
        broadcast_to_passenger(trip.passenger_id, "trip_cancelled", %{
          trip_id: trip.id,
          reason: reason,
          cancelled_by: cancelled_by
        })

        broadcast_to_driver(trip.driver_id, "trip_cancelled", %{
          trip_id: trip.id,
          reason: reason,
          cancelled_by: cancelled_by
        })

        {:reply, {:ok, %{message: "Trip cancelled"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("board_passenger", %{"passenger_id" => passenger_id, "seat_number" => seat_number}, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        # Find and occupy seat
        seat = find_seat(trip.vehicle_id, seat_number)
        case Seat.occupy(seat.id) do
          {:ok, _} ->
            # Update trip status to boarding
            Trip.update_status(trip_id, :boarding)

            {:reply, {:ok, %{
              message: "Passenger boarded",
              seat: seat_number,
              trip_status: "boarding"
            }}, socket}
          {:error, reason} ->
            {:reply, {:error, %{reason: reason}}, socket}
        end
    end
  end

  def handle_in("alight_passenger", %{"passenger_id" => passenger_id}, socket) do
    trip_id = socket.assigns.trip_id

    # Release passenger's seat
    case find_passenger_seat(passenger_id, trip_id) do
      nil -> {:reply, {:error, %{reason: "Seat not found"}}, socket}
      seat ->
        Seat.release(seat.id)
        {:reply, {:ok, %{message: "Passenger alighted"}}, socket}
    end
  end

  def handle_in("update_trip_status", %{"status" => status}, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.update_status(trip_id, String.to_atom(status)) do
      {:ok, trip} ->
        broadcast(socket, "status_updated", %{
          trip_id: trip.id,
          status: trip.status,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{trip: trip}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("get_trip_details", _payload, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        # Get seat information
        seats = Seat.get_by_vehicle(trip.vehicle_id, trip_id: trip_id)

        {:reply, {:ok, %{
          trip: trip,
          seats: seats,
          passenger_count: Enum.count(seats, &(&1.status == :occupied))
        }}, socket}
    end
  end

  defp release_seats(trip) do
    seats = Seat.get_by_vehicle(trip.vehicle_id, trip_id: trip.id)
    Enum.each(seats, &Seat.release/1)
  end

  defp find_seat(vehicle_id, seat_number) do
    Seat.get_by_vehicle(vehicle_id)
    |> Enum.find(&(&1.seat_number == seat_number))
  end

  defp find_passenger_seat(passenger_id, trip_id) do
    # Find seat occupied by passenger in this trip
    nil # Simplified
  end

  defp get_driver_location(driver_id) do
    case Driver.get(driver_id) do
      nil -> nil
      driver -> driver.current_location
    end
  end

  defp broadcast_to_passenger(passenger_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("passenger:#{passenger_id}", event, payload)
  end

  defp broadcast_to_driver(driver_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("driver:#{driver_id}", event, payload)
  end
end
