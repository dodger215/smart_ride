# lib/smart_bus_web/channels/driver_channel.ex
defmodule SmartBusWeb.DriverChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Driver
  alias SmartBus.DB.User
  alias SmartBus.DB.Vehicle
  alias SmartBus.DB.Trip

  def join("driver:" <> driver_id, _params, socket) do
    case Driver.get(driver_id) do
      nil -> {:error, %{reason: "Driver not found"}}
      _ ->
        socket = assign(socket, :driver_id, driver_id)
        {:ok, socket}
    end
  end

  def handle_in("register_driver", payload, socket) do
    # This is called after user registration to complete driver profile
    user_id = socket.assigns.user_id

    driver_data = %{
      user_id: user_id,
      driver_license: payload["driver_license"],
      license_expiry: payload["license_expiry"],
      identity_document: payload["identity_document"],
      total_seats: payload["total_seats"]
    }

    case Driver.create(driver_data) do
      {:ok, driver} ->
        {:reply, {:ok, %{driver: driver, message: "Driver registration submitted for approval"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("update_profile", payload, socket) do
    driver_id = socket.assigns.driver_id

    updates = Map.take(payload, ["driver_license", "license_expiry", "identity_document"])
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.new()

    # Get driver to update
    case Driver.get(driver_id) do
      nil -> {:reply, {:error, %{reason: "Driver not found"}}, socket}
      driver ->
        # Update user profile if name provided
        if payload["full_name"] do
          User.update(driver.user_id, %{full_name: payload["full_name"]})
        end

        # Update driver profile
        updated_driver = struct(driver, updates)
        {:reply, {:ok, %{driver: updated_driver}}, socket}
    end
  end

  def handle_in("upload_documents", %{"documents" => documents}, socket) do
    driver_id = socket.assigns.driver_id

    # Process uploaded documents
    # In production, upload to cloud storage and save URLs
    document_urls = Enum.map(documents, fn doc ->
      # Upload and get URL
      "https://storage.example.com/#{doc.filename}"
    end)

    # Update driver with document URLs
    {:reply, {:ok, %{documents: document_urls, message: "Documents uploaded successfully"}}, socket}
  end

  def handle_in("verify_account", %{"admin_id" => admin_id}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.get(driver_id) do
      nil -> {:reply, {:error, %{reason: "Driver not found"}}, socket}
      driver ->
        # Update driver status to verified
        Driver.change_status(driver_id, :verified)

        # Notify driver
        broadcast(socket, "account_verified", %{
          driver_id: driver_id,
          verified_by: admin_id,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{message: "Account verified successfully"}}, socket}
    end
  end

  def handle_in("suspend_account", %{"reason" => reason}, socket) do
    driver_id = socket.assigns.driver_id

    case Driver.change_status(driver_id, :suspended) do
      {:ok, _} ->
        broadcast(socket, "account_suspended", %{
          driver_id: driver_id,
          reason: reason,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{message: "Account suspended"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("view_vehicles", _payload, socket) do
    driver_id = socket.assigns.driver_id

    vehicles = Vehicle.get_by_driver(driver_id)

    {:reply, {:ok, %{vehicles: vehicles}}, socket}
  end

  def handle_in("view_active_trips", _payload, socket) do
    driver_id = socket.assigns.driver_id

    trips = Trip.get_active_driver_trips(driver_id)

    {:reply, {:ok, %{trips: trips}}, socket}
  end

  def handle_in("view_earnings", %{"period" => period}, socket) do
    driver_id = socket.assigns.driver_id

    earnings = case period do
      "today" -> calculate_daily_earnings(driver_id)
      "week" -> calculate_weekly_earnings(driver_id)
      "month" -> calculate_monthly_earnings(driver_id)
      "all" -> calculate_total_earnings(driver_id)
      _ -> %{error: "Invalid period"}
    end

    {:reply, {:ok, %{earnings: earnings}}, socket}
  end

  defp calculate_daily_earnings(driver_id) do
    %{
      date: Date.utc_today(),
      amount: 0.0, # Calculate from payments
      trips: 0,
      average_fare: 0.0
    }
  end

  defp calculate_weekly_earnings(driver_id) do
    %{
      week_start: Date.beginning_of_week(Date.utc_today()),
      week_end: Date.end_of_week(Date.utc_today()),
      amount: 0.0,
      trips: 0
    }
  end

  defp calculate_monthly_earnings(driver_id) do
    %{
      month: Date.utc_today().month,
      year: Date.utc_today().year,
      amount: 0.0,
      trips: 0
    }
  end

  defp calculate_total_earnings(driver_id) do
    %{
      total_amount: 0.0,
      total_trips: 0,
      average_rating: 0.0
    }
  end
end
