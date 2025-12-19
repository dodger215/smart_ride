defmodule SmartBusWeb.TrackingChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.TrackingChannel

  describe "join" do
    test "join tracking:trip:trip_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:trip:trip-1")
      assert true
    end

    test "join tracking:vehicle:vehicle_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:vehicle:vehicle-1")
      assert true
    end
  end

  describe "handle_in" do
    test "start_tracking" do
      {:ok, _, socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:trip:trip-1")

      ref = push(socket, "start_tracking", %{
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "update_location" do
      {:ok, _, socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:vehicle:vehicle-1")

      ref = push(socket, "update_location", %{
        "vehicle_id" => "vehicle-1",
        "location" => %{"lat" => 40.7128, "lng" => -74.0060}
      })

      assert_reply ref, :ok, _payload
    end

    test "stop_tracking" do
      {:ok, _, socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:trip:trip-1")

      ref = push(socket, "stop_tracking", %{
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_current_location" do
      {:ok, _, socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:vehicle:vehicle-1")

      ref = push(socket, "get_current_location", %{
        "vehicle_id" => "vehicle-1"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :location)
    end

    test "calculate_eta" do
      {:ok, _, socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:trip:trip-1")

      ref = push(socket, "calculate_eta", %{
        "from" => %{"lat" => 40.7128, "lng" => -74.0060},
        "to" => %{"lat" => 40.7580, "lng" => -73.9855}
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:eta_minutes])
    end

    test "calculate_total_distance" do
      {:ok, _, socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:trip:trip-1")

      ref = push(socket, "calculate_total_distance", %{
        "route" => [
          %{"lat" => 40.7128, "lng" => -74.0060},
          %{"lat" => 40.7580, "lng" => -73.9855}
        ]
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:distance_km])
    end

    test "get_route_progress" do
      {:ok, _, socket} = subscribe_and_join(socket(), TrackingChannel, "tracking:trip:trip-1")

      ref = push(socket, "get_route_progress", %{
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:progress_percentage])
    end
  end
end
