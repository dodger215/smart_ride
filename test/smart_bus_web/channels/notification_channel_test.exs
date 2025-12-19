defmodule SmartBusWeb.NotificationChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.NotificationChannel

  describe "join" do
    test "join notification:user:user_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), NotificationChannel, "notification:user:user-1")
      assert true
    end

    test "join notification:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), NotificationChannel, "notification:system")
      assert true
    end
  end

  describe "handle_in" do
    test "send_notification" do
      {:ok, _, socket} = subscribe_and_join(socket(), NotificationChannel, "notification:user:user-1")

      ref = push(socket, "send_notification", %{
        "user_id" => "user-1",
        "type" => "ride_accepted",
        "data" => %{"driver_name" => "John", "eta" => 5}
      })

      assert_reply ref, :ok, _payload
    end

    test "mark_as_read" do
      {:ok, _, socket} = subscribe_and_join(socket(), NotificationChannel, "notification:user:user-1")

      ref = push(socket, "mark_as_read", %{
        "notification_id" => "notif-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_notifications" do
      {:ok, _, socket} = subscribe_and_join(socket(), NotificationChannel, "notification:user:user-1")

      ref = push(socket, "get_notifications", %{
        "user_id" => "user-1",
        "limit" => 20
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "get_unread_count" do
      {:ok, _, socket} = subscribe_and_join(socket(), NotificationChannel, "notification:user:user-1")

      ref = push(socket, "get_unread_count", %{
        "user_id" => "user-1"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:count])
    end

    test "set_notification_preferences" do
      {:ok, _, socket} = subscribe_and_join(socket(), NotificationChannel, "notification:user:user-1")

      ref = push(socket, "set_notification_preferences", %{
        "user_id" => "user-1",
        "preferences" => %{
          "sms" => true,
          "push" => true,
          "email" => false
        }
      })

      assert_reply ref, :ok, _payload
    end
  end
end
