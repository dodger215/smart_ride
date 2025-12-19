defmodule SmartBusWeb.GPSChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.GPSChannel

  describe "join" do
    test "join gps:vehicle:vehicle_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), GPSChannel, "gps:vehicle:vehicle-1")
      assert true
    end

    test "join gps:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")
      assert true
    end
  end

  describe "handle_in" do
    test "log_location" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:vehicle:vehicle-1")

      ref = push(socket, "log_location", %{
        "vehicle_id" => "vehicle-1",
        "location" => %{"lat" => 40.7128, "lng" => -74.0060},
        "speed" => 45,
        "heading" => 90
      })

      assert_reply ref, :ok, _payload
    end

    test "calculate_route" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")

      ref = push(socket, "calculate_route", %{
        "origin" => %{"lat" => 40.7128, "lng" => -74.0060},
        "destination" => %{"lat" => 40.7580, "lng" => -73.9855}
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :route)
    end

    test "calculate_savings" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")

      ref = push(socket, "calculate_savings", %{
        "optimized_route" => [
          %{"lat" => 40.7128, "lng" => -74.0060},
          %{"lat" => 40.7580, "lng" => -73.9855}
        ]
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:savings])
    end

    test "detect_bus_stops" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")

      ref = push(socket, "detect_bus_stops", %{
        "locations" => [
          %{"lat" => 40.7128, "lng" => -74.0060},
          %{"lat" => 40.7580, "lng" => -73.9855}
        ]
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "get_gps_history" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:vehicle:vehicle-1")

      ref = push(socket, "get_gps_history", %{
        "vehicle_id" => "vehicle-1",
        "start_time" => DateTime.utc_now(),
        "end_time" => DateTime.utc_now()
      })

      assert_reply ref, :ok, _payload
    end

    test "analyze_speed_patterns" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")

      ref = push(socket, "analyze_speed_patterns", %{
        "vehicle_id" => "vehicle-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "create_geofence" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")

      ref = push(socket, "create_geofence", %{
        "name" => "downtown",
        "center" => %{"lat" => 40.7128, "lng" => -74.0060},
        "radius" => 1.0
      })

      assert_reply ref, :ok, _payload
    end

    test "update_geofence" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")

      ref = push(socket, "update_geofence", %{
        "geofence_id" => "geofence-1",
        "radius" => 2.0
      })

      assert_reply ref, :ok, _payload
    end

    test "delete_geofence" do
      {:ok, _, socket} = subscribe_and_join(socket(), GPSChannel, "gps:system")

      ref = push(socket, "delete_geofence", %{
        "geofence_id" => "geofence-1"
      })

      assert_reply ref, :ok, _payload
    end
  end
end
