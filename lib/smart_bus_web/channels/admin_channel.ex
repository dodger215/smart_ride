# lib/smart_bus_web/channels/admin_channel.ex
defmodule SmartBusWeb.AdminChannel do
  use Phoenix.Channel
  alias SmartBus.DB.User
  alias SmartBus.DB.Driver
  alias SmartBus.DB.Vehicle
  alias SmartBus.DB.Trip
  alias SmartBus.DB.Payment
  alias SmartBus.DB.Dispute
  alias SmartBus.DB.FareConfig

  def join("admin:system", _params, socket) do
    # Admin authentication would happen here
    {:ok, socket}
  end

  def join("admin:dashboard", _params, socket) do
    {:ok, socket}
  end

  def handle_in("approve_driver", %{"driver_id" => driver_id, "admin_id" => admin_id}, socket) do
    case Driver.change_status(driver_id, :verified) do
      {:ok, driver} ->
        # Notify driver
        SmartBusWeb.Endpoint.broadcast("driver:#{driver_id}", "driver_approved", %{
          admin_id: admin_id,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{message: "Driver approved"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("verify_vehicle", %{"vehicle_id" => vehicle_id, "admin_id" => admin_id}, socket) do
    case Vehicle.update_status(vehicle_id, :approved) do
      {:ok, vehicle} ->
        # Notify driver
        SmartBusWeb.Endpoint.broadcast("vehicle:driver:#{vehicle.driver_id}", "vehicle_approved", %{
          admin_id: admin_id,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{message: "Vehicle verified"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("suspend_user", %{"user_id" => user_id, "reason" => reason}, socket) do
    case User.change_status(user_id, :suspended) do
      {:ok, user} ->
        # Notify user
        SmartBusWeb.Endpoint.broadcast("user:#{user_id}", "account_suspended", %{
          reason: reason,
          timestamp: DateTime.utc_now()
        })

        {:reply, {:ok, %{message: "User suspended"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("monitor_trips", %{"status" => status, "limit" => limit}, socket) do
    # Get trips with specific status
    trips = case status do
      "active" -> get_active_trips(limit)
      "completed" -> get_completed_trips(limit)
      "cancelled" -> get_cancelled_trips(limit)
      _ -> []
    end

    {:reply, {:ok, %{trips: trips, count: length(trips)}}, socket}
  end

  def handle_in("view_reports", %{"report_type" => report_type, "date_range" => date_range}, socket) do
    reports = generate_report(report_type, date_range)
    {:reply, {:ok, %{report: reports}}, socket}
  end

  def handle_in("configure_fares", %{"lane" => lane, "config" => config}, socket) do
    fare_config = %{
      lane: lane,
      base_fare: config["base_fare"],
      per_km_fare: config["per_km_fare"],
      per_minute_fare: config["per_minute_fare"],
      min_fare: config["min_fare"],
      max_fare: config["max_fare"],
      commission_rate: config["commission_rate"],
      platform_fee: config["platform_fee"]
    }

    case FareConfig.create(fare_config) do
      {:ok, config} ->
        {:reply, {:ok, %{config: config, message: "Fare configuration updated"}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("handle_dispute", %{"dispute_id" => dispute_id, "resolution" => resolution}, socket) do
    case Dispute.get(dispute_id) do
      nil -> {:reply, {:error, %{reason: "Dispute not found"}}, socket}
      dispute ->
        # Update dispute with resolution
        Dispute.resolve(dispute_id, resolution["notes"], %{
          refund_amount: resolution["refund_amount"],
          penalty_amount: resolution["penalty_amount"]
        })

        # Notify involved parties
        notify_dispute_resolution(dispute, resolution)

        {:reply, {:ok, %{message: "Dispute resolved"}}, socket}
    end
  end

  def handle_in("get_system_stats", _payload, socket) do
    stats = %{
      total_users: count_users(),
      total_drivers: count_drivers(),
      active_trips: count_active_trips(),
      today_earnings: calculate_today_earnings(),
      pending_approvals: count_pending_approvals(),
      open_disputes: count_open_disputes()
    }

    {:reply, {:ok, %{stats: stats}}, socket}
  end

  def handle_in("view_user_details", %{"user_id" => user_id}, socket) do
    case User.get(user_id) do
      nil -> {:reply, {:error, %{reason: "User not found"}}, socket}
      user ->
        # Get additional info based on role
        extra_info = case user.role do
          :driver -> get_driver_details(user_id)
          :passenger -> get_passenger_details(user_id)
          _ -> %{}
        end

        {:reply, {:ok, %{user: user, details: extra_info}}, socket}
    end
  end

  defp get_active_trips(limit) do
    # Get active trips
    []
  end

  defp get_completed_trips(limit) do
    # Get completed trips
    []
  end

  defp get_cancelled_trips(limit) do
    # Get cancelled trips
    []
  end

  defp generate_report(report_type, date_range) do
    case report_type do
      "revenue" -> generate_revenue_report(date_range)
      "trips" -> generate_trips_report(date_range)
      "users" -> generate_users_report(date_range)
      _ -> %{}
    end
  end

  defp generate_revenue_report(date_range) do
    %{
      total_revenue: 0.0,
      platform_earnings: 0.0,
      driver_earnings: 0.0,
      by_payment_method: %{}
    }
  end

  defp generate_trips_report(date_range) do
    %{
      total_trips: 0,
      completed_trips: 0,
      cancelled_trips: 0,
      average_rating: 0.0
    }
  end

  defp generate_users_report(date_range) do
    %{
      new_users: 0,
      active_users: 0,
      user_growth: 0.0
    }
  end

  defp count_users() do
    # Count total users
    0
  end

  defp count_drivers() do
    # Count total drivers
    0
  end

  defp count_active_trips() do
    # Count active trips
    0
  end

  defp calculate_today_earnings() do
    # Calculate today's earnings
    0.0
  end

  defp count_pending_approvals() do
    # Count pending driver/vehicle approvals
    0
  end

  defp count_open_disputes() do
    # Count open disputes
    0
  end

  defp get_driver_details(user_id) do
    %{
      trips_completed: 0,
      average_rating: 0.0,
      earnings: 0.0
    }
  end

  defp get_passenger_details(user_id) do
    %{
      trips_taken: 0,
      average_rating: 0.0,
      total_spent: 0.0
    }
  end

  defp notify_dispute_resolution(dispute, resolution) do
    # Notify user about dispute resolution
    SmartBusWeb.Endpoint.broadcast("user:#{dispute.user_id}", "dispute_resolved", %{
      dispute_id: dispute.id,
      resolution: resolution["notes"],
      refund_amount: resolution["refund_amount"]
    })
  end
end
