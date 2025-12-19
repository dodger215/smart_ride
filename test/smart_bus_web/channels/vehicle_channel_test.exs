defmodule SmartBusWeb.VehicleChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.VehicleChannel

  describe "join" do
    test "join vehicle:vehicle_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")
      assert true
    end

    test "join vehicle:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:system")
      assert true
    end
  end

  describe "handle_in" do
    test "register_vehicle" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:system")

      ref = push(socket, "register_vehicle", %{
        "driver_id" => "driver-1",
        "registration_number" => "ABC-123",
        "model" => "Mercedes Sprinter",
        "capacity" => 50
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :vehicle_id)
    end

    test "update_vehicle_status" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "update_vehicle_status", %{
        "vehicle_id" => "vehicle-1",
        "status" => "active"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_vehicle_details" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "get_vehicle_details", %{
        "vehicle_id" => "vehicle-1"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :vehicle)
    end

    test "update_vehicle_location" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "update_vehicle_location", %{
        "vehicle_id" => "vehicle-1",
        "location" => %{"lat" => 40.7128, "lng" => -74.0060}
      })

      assert_reply ref, :ok, _payload
    end

    test "perform_maintenance" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "perform_maintenance", %{
        "vehicle_id" => "vehicle-1",
        "maintenance_type" => "regular",
        "description" => "Oil change"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_maintenance_history" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "get_maintenance_history", %{
        "vehicle_id" => "vehicle-1"
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "get_fuel_status" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "get_fuel_status", %{
        "vehicle_id" => "vehicle-1"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:fuel_percentage])
    end

    test "add_vehicle_to_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "add_vehicle_to_trip", %{
        "vehicle_id" => "vehicle-1",
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "remove_vehicle_from_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), VehicleChannel, "vehicle:vehicle-1")

      ref = push(socket, "remove_vehicle_from_trip", %{
        "vehicle_id" => "vehicle-1",
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end
  end
end
