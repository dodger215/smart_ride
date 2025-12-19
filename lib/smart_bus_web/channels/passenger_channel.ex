defmodule SmartBusWeb.PassengerChannel do
  use Phoenix.Channel

  def join("passenger:" <> passenger_id, _payload, socket) do
    if authorized?(passenger_id) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("create_profile", payload, socket) do
    passenger_id = extract_passenger_id(socket)

    profile_data = %{
      full_name: payload["full_name"],
      profile_picture: payload["profile_picture"],
      preferences: payload["preferences"] || %{},
      emergency_contact: payload["emergency_contact"]
    }

    SmartBus.DB.update(:user, passenger_id, profile_data)
    {:reply, {:ok, %{message: "Profile created successfully"}}, socket}
  end

  def handle_in("view_profile", _payload, socket) do
    passenger_id = extract_passenger_id(socket)

    case SmartBus.DB.get(:user, passenger_id) do
      nil -> {:reply, {:error, %{reason: "Profile not found"}}, socket}
      user -> {:reply, {:ok, user.data}, socket}
    end
  end

  def handle_in("view_ride_history", %{"page" => page, "limit" => limit}, socket) do
    passenger_id = extract_passenger_id(socket)

    trips = SmartBus.DB.query(:trip, passenger_id: passenger_id)
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.slice((page - 1) * limit, limit)

    {:reply, {:ok, %{trips: trips, page: page, total: length(trips)}}, socket}
  end

  defp extract_passenger_id(socket) do
    # Extract from socket assigns
    socket.assigns.user_id
  end

  defp authorized?(_passenger_id) do
    # Implement authorization logic
    true
  end
end
