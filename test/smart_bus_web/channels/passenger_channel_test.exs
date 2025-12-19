defmodule SmartBusWeb.PassengerChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.PassengerChannel

  describe "join" do
    test "join passenger:user:user_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")
      assert true
    end

    test "join passenger:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:system")
      assert true
    end
  end

  describe "handle_in" do
    test "request_ride" do
      {:ok, _, socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")

      ref = push(socket, "request_ride", %{
        "passenger_id" => "user-1",
        "origin" => %{"lat" => 40.7128, "lng" => -74.0060},
        "destination" => %{"lat" => 40.7580, "lng" => -73.9855}
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :ride_id)
    end

    test "cancel_ride" do
      {:ok, _, socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")

      ref = push(socket, "cancel_ride", %{
        "ride_id" => "ride-1",
        "reason" => "driver_taking_too_long"
      })

      assert_reply ref, :ok, _payload
    end

    test "track_ride" do
      {:ok, _, socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")

      ref = push(socket, "track_ride", %{
        "ride_id" => "ride-1"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :driver_location)
    end

    test "get_ride_history" do
      {:ok, _, socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")

      ref = push(socket, "get_ride_history", %{
        "passenger_id" => "user-1",
        "limit" => 10
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "rate_trip" do
      {:ok, _, socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")

      ref = push(socket, "rate_trip", %{
        "ride_id" => "ride-1",
        "rating" => 5,
        "comment" => "Great driver!"
      })

      assert_reply ref, :ok, _payload
    end

    test "add_favorite_location" do
      {:ok, _, socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")

      ref = push(socket, "add_favorite_location", %{
        "passenger_id" => "user-1",
        "label" => "home",
        "location" => %{"lat" => 40.7128, "lng" => -74.0060}
      })

      assert_reply ref, :ok, _payload
    end

    test "get_favorite_locations" do
      {:ok, _, socket} = subscribe_and_join(socket(), PassengerChannel, "passenger:user:user-1")

      ref = push(socket, "get_favorite_locations", %{
        "passenger_id" => "user-1"
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end
  end
end
