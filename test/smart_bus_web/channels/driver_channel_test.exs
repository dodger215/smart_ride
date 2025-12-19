defmodule SmartBusWeb.DriverChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.DriverChannel

  describe "join" do
    test "join driver:driver_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")
      assert true
    end
  end

  describe "handle_in" do
    test "update_location" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "update_location", %{
        "driver_id" => "driver-1",
        "location" => %{"lat" => 40.7128, "lng" => -74.0060}
      })

      assert_reply ref, :ok, _payload
    end

    test "start_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "start_trip", %{
        "driver_id" => "driver-1",
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "end_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "end_trip", %{
        "driver_id" => "driver-1",
        "trip_id" => "trip-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "accept_ride" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "accept_ride", %{
        "driver_id" => "driver-1",
        "ride_request_id" => "ride-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "decline_ride" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "decline_ride", %{
        "driver_id" => "driver-1",
        "ride_request_id" => "ride-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "calculate_daily_earnings" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "calculate_daily_earnings", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "calculate_weekly_earnings" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "calculate_weekly_earnings", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "calculate_monthly_earnings" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "calculate_monthly_earnings", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "calculate_total_earnings" do
      {:ok, _, socket} = subscribe_and_join(socket(), DriverChannel, "driver:driver-1")

      ref = push(socket, "calculate_total_earnings", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, _payload
    end
  end
end
