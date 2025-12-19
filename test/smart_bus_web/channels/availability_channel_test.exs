defmodule SmartBusWeb.AvailabilityChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.AvailabilityChannel

  describe "join" do
    test "join availability:driver topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), AvailabilityChannel, "availability:driver")
      assert true
    end

    test "join availability:dispatcher topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), AvailabilityChannel, "availability:dispatcher")
      assert true
    end
  end

  describe "handle_in" do
    test "set_available status" do
      {:ok, _, socket} = subscribe_and_join(socket(), AvailabilityChannel, "availability:driver")

      ref = push(socket, "set_available", %{
        "driver_id" => "driver-1",
        "location" => %{"lat" => 40.7128, "lng" => -74.0060}
      })

      assert_reply ref, :ok, _payload
    end

    test "set_busy status" do
      {:ok, _, socket} = subscribe_and_join(socket(), AvailabilityChannel, "availability:driver")

      ref = push(socket, "set_busy", %{
        "driver_id" => "driver-1",
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "set_offline status" do
      {:ok, _, socket} = subscribe_and_join(socket(), AvailabilityChannel, "availability:driver")

      ref = push(socket, "set_offline", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_vehicle_info" do
      {:ok, _, socket} = subscribe_and_join(socket(), AvailabilityChannel, "availability:driver")

      ref = push(socket, "get_vehicle_info", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "find_nearby_passengers" do
      {:ok, _, socket} = subscribe_and_join(socket(), AvailabilityChannel, "availability:dispatcher")

      ref = push(socket, "find_nearby_passengers", %{
        "location" => %{"lat" => 40.7128, "lng" => -74.0060},
        "radius" => 5
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end
  end
end
