defmodule SmartBusWeb.AdminChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.AdminChannel

  describe "join" do
    test "join admin:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), AdminChannel, "admin:system")
      assert true
    end

    test "join admin:dashboard topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), AdminChannel, "admin:dashboard")
      assert true
    end
  end

  describe "handle_in" do
    test "approve_driver message" do
      {:ok, _, socket} = subscribe_and_join(socket(), AdminChannel, "admin:system")

      ref = push(socket, "approve_driver", %{
        "driver_id" => "test-driver-1",
        "admin_id" => "test-admin-1"
      })

      # We expect a reply
      assert_reply ref, :ok, _payload
    end

    test "verify_vehicle message" do
      {:ok, _, socket} = subscribe_and_join(socket(), AdminChannel, "admin:system")

      ref = push(socket, "verify_vehicle", %{
        "vehicle_id" => "test-vehicle-1",
        "admin_id" => "test-admin-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "suspend_user message" do
      {:ok, _, socket} = subscribe_and_join(socket(), AdminChannel, "admin:system")

      ref = push(socket, "suspend_user", %{
        "user_id" => "test-user-1",
        "reason" => "violations"
      })

      assert_reply ref, :ok, _payload
    end

    test "monitor_trips active" do
      {:ok, _, socket} = subscribe_and_join(socket(), AdminChannel, "admin:dashboard")

      ref = push(socket, "monitor_trips", %{
        "status" => "active",
        "limit" => 10
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :trips)
      assert Map.has_key?(payload, :count)
    end

    test "monitor_trips completed" do
      {:ok, _, socket} = subscribe_and_join(socket(), AdminChannel, "admin:dashboard")

      ref = push(socket, "monitor_trips", %{
        "status" => "completed",
        "limit" => 10
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :trips)
    end

    test "monitor_trips cancelled" do
      {:ok, _, socket} = subscribe_and_join(socket(), AdminChannel, "admin:dashboard")

      ref = push(socket, "monitor_trips", %{
        "status" => "cancelled",
        "limit" => 10
      })

      assert_reply ref, :ok, _payload
    end

    test "view_reports" do
      {:ok, _, socket} = subscribe_and_join(socket(), AdminChannel, "admin:dashboard")

      ref = push(socket, "view_reports", %{
        "report_type" => "revenue",
        "date_range" => "weekly"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :report)
    end
  end
end
