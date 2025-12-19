defmodule SmartBusWeb.RideRequestChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.RideRequestChannel

  describe "join" do
    test "join ride_request:passenger:user_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:passenger:user-1")
      assert true
    end

    test "join ride_request:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:system")
      assert true
    end
  end

  describe "handle_in" do
    test "request_ride" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:passenger:user-1")

      ref = push(socket, "request_ride", %{
        "passenger_id" => "user-1",
        "origin" => %{"lat" => 40.7128, "lng" => -74.0060},
        "destination" => %{"lat" => 40.7580, "lng" => -73.9855},
        "preferred_vehicle_type" => "standard"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :request_id)
    end

    test "cancel_request" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:passenger:user-1")

      ref = push(socket, "cancel_request", %{
        "request_id" => "request-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "update_request_location" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:passenger:user-1")

      ref = push(socket, "update_request_location", %{
        "request_id" => "request-1",
        "location" => %{"lat" => 40.7150, "lng" => -74.0050}
      })

      assert_reply ref, :ok, _payload
    end

    test "get_nearby_drivers" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:system")

      ref = push(socket, "get_nearby_drivers", %{
        "location" => %{"lat" => 40.7128, "lng" => -74.0060},
        "radius" => 5
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "get_estimated_fare" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:passenger:user-1")

      ref = push(socket, "get_estimated_fare", %{
        "origin" => %{"lat" => 40.7128, "lng" => -74.0060},
        "destination" => %{"lat" => 40.7580, "lng" => -73.9855}
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:fare])
    end

    test "accept_assigned_driver" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:passenger:user-1")

      ref = push(socket, "accept_assigned_driver", %{
        "request_id" => "request-1",
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "reject_assigned_driver" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:passenger:user-1")

      ref = push(socket, "reject_assigned_driver", %{
        "request_id" => "request-1",
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_vehicle_info" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideRequestChannel, "ride_request:system")

      ref = push(socket, "get_vehicle_info", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :vehicle)
    end
  end
end
