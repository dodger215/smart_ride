defmodule SmartBusWeb.SeatManagementChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.SeatManagementChannel

  describe "join" do
    test "join seat_management:vehicle:vehicle_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:vehicle:vehicle-1")
      assert true
    end

    test "join seat_management:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:system")
      assert true
    end
  end

  describe "handle_in" do
    test "get_available_seats" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:vehicle:vehicle-1")

      ref = push(socket, "get_available_seats", %{
        "vehicle_id" => "vehicle-1"
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "reserve_seat" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:vehicle:vehicle-1")

      ref = push(socket, "reserve_seat", %{
        "vehicle_id" => "vehicle-1",
        "seat_id" => "seat-5",
        "passenger_id" => "pass-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "release_seat" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:vehicle:vehicle-1")

      ref = push(socket, "release_seat", %{
        "vehicle_id" => "vehicle-1",
        "seat_id" => "seat-5"
      })

      assert_reply ref, :ok, _payload
    end

    test "block_seat" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:vehicle:vehicle-1")

      ref = push(socket, "block_seat", %{
        "vehicle_id" => "vehicle-1",
        "seat_id" => "seat-3",
        "reason" => "maintenance"
      })

      assert_reply ref, :ok, _payload
    end

    test "unblock_seat" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:vehicle:vehicle-1")

      ref = push(socket, "unblock_seat", %{
        "vehicle_id" => "vehicle-1",
        "seat_id" => "seat-3"
      })

      assert_reply ref, :ok, _payload
    end

    test "update_seat_features" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:system")

      ref = push(socket, "update_seat_features", %{
        "seat_id" => "seat-1",
        "features" => %{"wheelchair_accessible" => true, "extra_legroom" => false}
      })

      assert_reply ref, :ok, _payload
    end

    test "get_seat_status" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:vehicle:vehicle-1")

      ref = push(socket, "get_seat_status", %{
        "vehicle_id" => "vehicle-1"
      })

      assert_reply ref, :ok, payload
      assert is_map(payload)
    end

    test "initialize_vehicle_seats" do
      {:ok, _, socket} = subscribe_and_join(socket(), SeatManagementChannel, "seat_management:system")

      ref = push(socket, "initialize_vehicle_seats", %{
        "vehicle_id" => "vehicle-1",
        "total_seats" => 50
      })

      assert_reply ref, :ok, _payload
    end
  end
end
