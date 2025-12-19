defmodule SmartBusWeb.SeatManagementChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Seat
  alias SmartBus.DB.Vehicle

  def join("seat_management:vehicle:" <> vehicle_id, _params, socket) do
    case Vehicle.get(vehicle_id) do
      nil -> {:error, %{reason: "Vehicle not found"}}
      _ ->
        socket = assign(socket, :vehicle_id, vehicle_id)
        {:ok, socket}
    end
  end

  def join("seat_management:trip:" <> trip_id, _params, socket) do
    socket = assign(socket, :trip_id, trip_id)
    {:ok, socket}
  end

  def handle_in("check_availability", %{"trip_id" => trip_id}, socket) do
    vehicle_id = socket.assigns.vehicle_id

    available_seats = Seat.get_available(vehicle_id, trip_id)
    seat_map = Seat.get_seat_map(vehicle_id, trip_id)

    {:reply, {:ok, %{
      available_seats: length(available_seats),
      seat_map: seat_map,
      seats: available_seats
    }}, socket}
  end

  def handle_in("reserve_seat", %{"seat_id" => seat_id, "passenger_id" => passenger_id}, socket) do
    trip_id = socket.assigns.trip_id
    reservation_id = UUID.uuid4()

    case Seat.reserve(seat_id, passenger_id, trip_id, reservation_id) do
      {:ok, seat} ->
        # Notify passenger
        broadcast_to_passenger(passenger_id, "seat_reserved", %{
          seat_id: seat.id,
          seat_number: seat.seat_number,
          trip_id: trip_id,
          reservation_id: reservation_id
        })

        {:reply, {:ok, %{
          seat: seat,
          reservation_id: reservation_id,
          message: "Seat reserved successfully"
        }}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("reserve_multiple_seats", %{"seat_ids" => seat_ids, "passenger_id" => passenger_id}, socket) do
    trip_id = socket.assigns.trip_id
    reservation_id = UUID.uuid4()

    case Seat.reserve_multiple(seat_ids, passenger_id, trip_id, reservation_id) do
      {:ok, seats} ->
        broadcast_to_passenger(passenger_id, "seats_reserved", %{
          seat_ids: Enum.map(seats, & &1.id),
          trip_id: trip_id,
          reservation_id: reservation_id
        })

        {:reply, {:ok, %{
          seats: seats,
          reservation_id: reservation_id,
          message: "Seats reserved successfully"
        }}, socket}
      {:error, reason, unavailable_seats} ->
        {:reply, {:error, %{
          reason: reason,
          unavailable_seats: unavailable_seats
        }}, socket}
    end
  end

  def handle_in("release_seat", %{"seat_id" => seat_id}, socket) do
    case Seat.release(seat_id) do
      {:ok, _} ->
        {:reply, {:ok, %{message: "Seat released"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("update_capacity", %{"total_seats" => total_seats}, socket) do
    vehicle_id = socket.assigns.vehicle_id

    # This would update vehicle capacity
    # For now, just acknowledge
    {:reply, {:ok, %{message: "Capacity update received"}}, socket}
  end

  def handle_in("get_seat_details", %{"seat_id" => seat_id}, socket) do
    case Seat.get(seat_id) do
      nil -> {:reply, {:error, %{reason: "Seat not found"}}, socket}
      seat -> {:reply, {:ok, %{seat: seat}}, socket}
    end
  end

  def handle_in("block_seat", %{"seat_id" => seat_id, "reason" => reason}, socket) do
    case Seat.block(seat_id, reason) do
      {:ok, seat} ->
        broadcast(socket, "seat_blocked", %{
          seat_id: seat.id,
          reason: reason,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{seat: seat, message: "Seat blocked"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("unblock_seat", %{"seat_id" => seat_id}, socket) do
    case Seat.unblock(seat_id) do
      {:ok, seat} ->
        broadcast(socket, "seat_unblocked", %{
          seat_id: seat.id,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{seat: seat, message: "Seat unblocked"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("find_seats_with_features", %{"features" => features}, socket) do
    vehicle_id = socket.assigns.vehicle_id
    trip_id = socket.assigns.trip_id

    features_atoms = Enum.map(features, &String.to_atom/1)
    seats = Seat.find_seats_with_features(vehicle_id, features_atoms, trip_id)

    {:reply, {:ok, %{seats: seats, count: length(seats)}}, socket}
  end

  def handle_in("update_seat_features", %{"seat_id" => seat_id, "features" => features}, socket) do
    # Update seat features
    # Implementation depends on Seat.update method
    {:reply, {:ok, %{message: "Features updated"}}, socket}
  end

  defp broadcast_to_passenger(passenger_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("passenger:#{passenger_id}", event, payload)
  end
end
