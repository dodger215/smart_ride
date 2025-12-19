defmodule SmartBusWeb.NotificationChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Notification

  def join("notification:user:" <> user_id, _params, socket) do
    socket = assign(socket, :user_id, user_id)
    {:ok, socket}
  end

  def join("notification:driver:" <> driver_id, _params, socket) do
    socket = assign(socket, :driver_id, driver_id)
    {:ok, socket}
  end

  def join("notification:passenger:" <> passenger_id, _params, socket) do
    socket = assign(socket, :passenger_id, passenger_id)
    {:ok, socket}
  end

  def handle_in("arrival_alert", %{
    "trip_id" => trip_id,
    "eta_minutes" => eta,
    "location" => location
  }, socket) do
    passenger_id = socket.assigns.passenger_id

    # Create notification
    Notification.create(%{
      user_id: passenger_id,
      title: "Bus Arriving Soon",
      body: "Your bus will arrive in #{eta} minutes",
      type: :ride_update,
      data: %{
        trip_id: trip_id,
        eta: eta,
        location: location
      }
    })

    # Send push notification (in production)
    send_push_notification(passenger_id, "Bus arriving in #{eta} minutes")

    {:reply, {:ok, %{message: "Arrival alert sent"}}, socket}
  end

  def handle_in("booking_confirmation", %{
    "trip_id" => trip_id,
    "driver_name" => driver_name,
    "vehicle_number" => vehicle_number,
    "pickup_time" => pickup_time
  }, socket) do
    passenger_id = socket.assigns.passenger_id

    Notification.create(%{
      user_id: passenger_id,
      title: "Booking Confirmed",
      body: "Your ride with #{driver_name} (#{vehicle_number}) is confirmed",
      type: :ride_update,
      data: %{
        trip_id: trip_id,
        driver_name: driver_name,
        vehicle_number: vehicle_number,
        pickup_time: pickup_time
      }
    })

    {:reply, {:ok, %{message: "Booking confirmation sent"}}, socket}
  end

  def handle_in("driver_assigned", %{
    "trip_id" => trip_id,
    "driver_id" => driver_id,
    "eta" => eta
  }, socket) do
    passenger_id = socket.assigns.passenger_id

    Notification.create(%{
      user_id: passenger_id,
      title: "Driver Assigned",
      body: "Driver is #{eta} minutes away",
      type: :ride_update,
      data: %{
        trip_id: trip_id,
        driver_id: driver_id,
        eta: eta
      }
    })

    {:reply, {:ok, %{message: "Driver assignment notification sent"}}, socket}
  end

  def handle_in("payment_success", %{
    "trip_id" => trip_id,
    "amount" => amount,
    "method" => method
  }, socket) do
    passenger_id = socket.assigns.passenger_id

    Notification.create(%{
      user_id: passenger_id,
      title: "Payment Successful",
      body: "Payment of #{amount} via #{method} was successful",
      type: :payment,
      data: %{
        trip_id: trip_id,
        amount: amount,
        method: method
      }
    })

    {:reply, {:ok, %{message: "Payment success notification sent"}}, socket}
  end

  def handle_in("ride_cancelled", %{
    "trip_id" => trip_id,
    "reason" => reason,
    "cancelled_by" => cancelled_by
  }, socket) do
    passenger_id = socket.assigns.passenger_id

    Notification.create(%{
      user_id: passenger_id,
      title: "Ride Cancelled",
      body: "Your ride was cancelled: #{reason}",
      type: :ride_update,
      data: %{
        trip_id: trip_id,
        reason: reason,
        cancelled_by: cancelled_by
      }
    })

    {:reply, {:ok, %{message: "Ride cancellation notification sent"}}, socket}
  end

  def handle_in("availability_update", %{
    "driver_id" => driver_id,
    "status" => status,
    "lane" => lane
  }, socket) do
    # Notify system/admin about driver availability
    SmartBusWeb.Endpoint.broadcast("admin:system", "driver_availability", %{
      driver_id: driver_id,
      status: status,
      lane: lane,
      timestamp: DateTime.utc_now()
    })

    {:reply, {:ok, %{message: "Availability update sent"}}, socket}
  end

  def handle_in("send_notification", %{
    "user_id" => user_id,
    "title" => title,
    "body" => body,
    "type" => type,
    "data" => data
  }, socket) do
    # General notification sending
    Notification.create(%{
      user_id: user_id,
      title: title,
      body: body,
      type: String.to_atom(type),
      data: data
    })

    # Send to specific user channel
    SmartBusWeb.Endpoint.broadcast("notification:user:#{user_id}", "new_notification", %{
      title: title,
      body: body,
      type: type,
      data: data,
      timestamp: DateTime.utc_now()
    })

    {:reply, {:ok, %{message: "Notification sent"}}, socket}
  end

  def handle_in("get_notifications", %{"unread_only" => unread_only}, socket) do
    user_id = socket.assigns.user_id

    notifications = if unread_only do
      Notification.get_unread(user_id)
    else
      # Get recent notifications
      []
    end

    {:reply, {:ok, %{notifications: notifications}}, socket}
  end

  def handle_in("mark_as_read", %{"notification_id" => notification_id}, socket) do
    Notification.mark_as_read(notification_id)
    {:reply, {:ok, %{message: "Notification marked as read"}}, socket}
  end

  def handle_in("mark_all_as_read", _payload, socket) do
    user_id = socket.assigns.user_id

    # Mark all user notifications as read
    # Implementation depends on notification storage

    {:reply, {:ok, %{message: "All notifications marked as read"}}, socket}
  end

  def handle_in("send_bulk_notification", %{
    "user_ids" => user_ids,
    "title" => title,
    "body" => body
  }, socket) do
    # Send notification to multiple users
    Enum.each(user_ids, fn user_id ->
      Notification.create(%{
        user_id: user_id,
        title: title,
        body: body,
        type: :system,
        data: %{}
      })
    end)

    {:reply, {:ok, %{message: "Bulk notification sent to #{length(user_ids)} users"}}, socket}
  end

  defp send_push_notification(user_id, message) do
    # Integrate with Firebase Cloud Messaging or similar
    IO.puts("Push notification to #{user_id}: #{message}")
  end
end
