defmodule SmartBusWeb.OfflineOperationsChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.OfflineOperationsChannel

  describe "join" do
    test "join offline:device:device_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), OfflineOperationsChannel, "offline:device:device-1")
      assert true
    end

    test "join offline:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), OfflineOperationsChannel, "offline:system")
      assert true
    end
  end

  describe "handle_in" do
    test "cache_offline_data" do
      {:ok, _, socket} = subscribe_and_join(socket(), OfflineOperationsChannel, "offline:device:device-1")

      ref = push(socket, "cache_offline_data", %{
        "device_id" => "device-1",
        "type" => "trips",
        "data" => [%{"trip_id" => "trip-1"}]
      })

      assert_reply ref, :ok, _payload
    end

    test "validate_offline_ticket" do
      {:ok, _, socket} = subscribe_and_join(socket(), OfflineOperationsChannel, "offline:system")

      ref = push(socket, "validate_offline_ticket", %{
        "ticket_id" => "ticket-1",
        "code" => "ABC123"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_cached_data" do
      {:ok, _, socket} = subscribe_and_join(socket(), OfflineOperationsChannel, "offline:device:device-1")

      ref = push(socket, "get_cached_data", %{
        "device_id" => "device-1",
        "type" => "routes"
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "sync_pending_operations" do
      {:ok, _, socket} = subscribe_and_join(socket(), OfflineOperationsChannel, "offline:device:device-1")

      ref = push(socket, "sync_pending_operations", %{
        "device_id" => "device-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "clear_cache" do
      {:ok, _, socket} = subscribe_and_join(socket(), OfflineOperationsChannel, "offline:device:device-1")

      ref = push(socket, "clear_cache", %{
        "device_id" => "device-1"
      })

      assert_reply ref, :ok, _payload
    end
  end
end
