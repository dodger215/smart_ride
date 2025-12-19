defmodule SmartBusWeb.RideManagementChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.RideManagementChannel

  describe "join" do
    test "join ride_management:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:system")
      assert true
    end

    test "join ride_management:trip:trip_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")
      assert true
    end
  end

  describe "handle_in" do
    test "create_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:system")

      ref = push(socket, "create_trip", %{
        "driver_id" => "driver-1",
        "vehicle_id" => "vehicle-1",
        "route" => "Route-1",
        "start_time" => DateTime.utc_now(),
        "estimated_end_time" => DateTime.utc_now()
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :trip_id)
    end

    test "add_passenger_to_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")

      ref = push(socket, "add_passenger_to_trip", %{
        "trip_id" => "trip-1",
        "passenger_id" => "pass-1",
        "seat_number" => 5
      })

      assert_reply ref, :ok, _payload
    end

    test "remove_passenger_from_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")

      ref = push(socket, "remove_passenger_from_trip", %{
        "trip_id" => "trip-1",
        "passenger_id" => "pass-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "start_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")

      ref = push(socket, "start_trip", %{
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "end_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")

      ref = push(socket, "end_trip", %{
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_trip_details" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")

      ref = push(socket, "get_trip_details", %{
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :trip)
    end

    test "get_trip_passengers" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")

      ref = push(socket, "get_trip_passengers", %{
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "find_passenger_seat" do
      {:ok, _, socket} = subscribe_and_join(socket(), RideManagementChannel, "ride_management:trip:trip-1")

      ref = push(socket, "find_passenger_seat", %{
        "trip_id" => "trip-1",
        "passenger_id" => "pass-1"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :seat_number)
    end
  end
end
