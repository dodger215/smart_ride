defmodule SmartBusWeb.VehicleChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Vehicle
  alias SmartBus.DB.Driver
  alias SmartBus.DB.Seat

  def join("vehicle:" <> vehicle_id, _params, socket) do
    case Vehicle.get(vehicle_id) do
      nil -> {:error, %{reason: "Vehicle not found"}}
      _ ->
        socket = assign(socket, :vehicle_id, vehicle_id)
        {:ok, socket}
    end
  end

  def join("vehicle:driver:" <> driver_id, _params, socket) do
    case Driver.get(driver_id) do
      nil -> {:error, %{reason: "Driver not found"}}
      _ ->
        socket = assign(socket, :driver_id, driver_id)
        {:ok, socket}
    end
  end

  def handle_in("register_vehicle", payload, socket) do
    driver_id = socket.assigns.driver_id

    vehicle_data = %{
      driver_id: driver_id,
      name: payload["name"],
      brand: payload["brand"],
      model: payload["model"],
      year: payload["year"],
      color: payload["color"],
      number_plate: payload["number_plate"],
      vehicle_license: payload["vehicle_license"],
      license_expiry: payload["license_expiry"],
      total_seats: payload["total_seats"],
      amenities: payload["amenities"] || [],
      photos: payload["photos"] || []
    }

    case Vehicle.create(vehicle_data) do
      {:ok, vehicle} ->
        # Create seats for the vehicle
        layout_config = %{
          total_seats: vehicle.total_seats,
          rows: payload["rows"],
          columns: payload["columns"]
        }

        Seat.create_for_vehicle(vehicle.id, layout_config)

        broadcast(socket, "vehicle_registered", %{
          vehicle_id: vehicle.id,
          status: vehicle.status
        })

        {:reply, {:ok, %{vehicle: vehicle, message: "Vehicle registration submitted"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("update_details", payload, socket) do
    vehicle_id = socket.assigns.vehicle_id

    updates = Map.take(payload, ["name", "color", "amenities", "seat_layout"])
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.new()

    case Vehicle.update(vehicle_id, updates) do
      {:ok, vehicle} ->
        broadcast(socket, "vehicle_updated", %{
          vehicle_id: vehicle.id,
          updates: updates
        })

        {:reply, {:ok, %{vehicle: vehicle}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("upload_photos", %{"photos" => photos}, socket) do
    vehicle_id = socket.assigns.vehicle_id

    # Process and upload photos
    photo_urls = Enum.map(photos, fn photo ->
      # Upload to cloud storage
      "https://storage.example.com/vehicles/#{vehicle_id}/#{photo.filename}"
    end)

    # Add photos to vehicle
    Enum.each(photo_urls, &Vehicle.add_photo(vehicle_id, &1))

    {:reply, {:ok, %{photos: photo_urls, message: "Photos uploaded successfully"}}, socket}
  end

  def handle_in("approve_vehicle", %{"admin_id" => admin_id}, socket) do
    vehicle_id = socket.assigns.vehicle_id

    case Vehicle.update_status(vehicle_id, :approved) do
      {:ok, vehicle} ->
        # Notify driver
        broadcast_to_driver(vehicle.driver_id, "vehicle_approved", %{
          vehicle_id: vehicle.id,
          approved_by: admin_id,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{vehicle: vehicle, message: "Vehicle approved"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("reject_vehicle", %{"admin_id" => admin_id, "reason" => reason}, socket) do
    vehicle_id = socket.assigns.vehicle_id

    case Vehicle.update_status(vehicle_id, :rejected) do
      {:ok, vehicle} ->
        broadcast_to_driver(vehicle.driver_id, "vehicle_rejected", %{
          vehicle_id: vehicle.id,
          rejected_by: admin_id,
          reason: reason,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{vehicle: vehicle, message: "Vehicle rejected"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("deactivate_vehicle", %{"reason" => reason}, socket) do
    vehicle_id = socket.assigns.vehicle_id

    case Vehicle.update_status(vehicle_id, :suspended) do
      {:ok, vehicle} ->
        broadcast(socket, "vehicle_deactivated", %{
          vehicle_id: vehicle.id,
          reason: reason,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{message: "Vehicle deactivated"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("get_seat_map", _payload, socket) do
    vehicle_id = socket.assigns.vehicle_id

    seat_map = Seat.get_seat_map(vehicle_id)

    {:reply, {:ok, %{seat_map: seat_map}}, socket}
  end

  def handle_in("check_availability", _payload, socket) do
    vehicle_id = socket.assigns.vehicle_id

    availability = Vehicle.get_with_availability(vehicle_id)

    {:reply, {:ok, %{availability: availability}}, socket}
  end

  defp broadcast_to_driver(driver_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("driver:#{driver_id}", event, payload)
  end
end
