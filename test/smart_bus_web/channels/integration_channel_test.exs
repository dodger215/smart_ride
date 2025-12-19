defmodule SmartBusWeb.IntegrationChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.IntegrationChannel

  describe "join" do
    test "join integration:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), IntegrationChannel, "integration:system")
      assert true
    end

    test "join integration:payment topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), IntegrationChannel, "integration:payment")
      assert true
    end
  end

  describe "handle_in" do
    test "call_maps_api" do
      {:ok, _, socket} = subscribe_and_join(socket(), IntegrationChannel, "integration:system")

      ref = push(socket, "call_maps_api", %{
        "action" => "get_directions",
        "params" => %{"origin" => "40.7128,-74.0060", "destination" => "40.7580,-73.9855"}
      })

      assert_reply ref, :ok, _payload
    end

    test "process_payment_gateway" do
      {:ok, _, socket} = subscribe_and_join(socket(), IntegrationChannel, "integration:payment")

      ref = push(socket, "process_payment_gateway", %{
        "gateway" => "stripe",
        "action" => "charge",
        "data" => %{"amount" => 5000, "currency" => "USD"}
      })

      assert_reply ref, :ok, _payload
    end

    test "send_sms_integration" do
      {:ok, _, socket} = subscribe_and_join(socket(), IntegrationChannel, "integration:system")

      ref = push(socket, "send_sms_integration", %{
        "phone" => "+1234567890",
        "message" => "Your OTP is 123456"
      })

      assert_reply ref, :ok, _payload
    end

    test "send_push_notification" do
      {:ok, _, socket} = subscribe_and_join(socket(), IntegrationChannel, "integration:system")

      ref = push(socket, "send_push_notification", %{
        "user_id" => "user-1",
        "title" => "Ride Accepted",
        "body" => "Driver is on the way"
      })

      assert_reply ref, :ok, _payload
    end

    test "process_webhook" do
      {:ok, _, socket} = subscribe_and_join(socket(), IntegrationChannel, "integration:system")

      ref = push(socket, "process_webhook", %{
        "source" => "stripe",
        "event" => "payment.success",
        "data" => %{"transaction_id" => "txn-123"}
      })

      assert_reply ref, :ok, _payload
    end
  end
end
