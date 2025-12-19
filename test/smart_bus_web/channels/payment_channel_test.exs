defmodule SmartBusWeb.PaymentChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.PaymentChannel

  describe "join" do
    test "join payment:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), PaymentChannel, "payment:system")
      assert true
    end

    test "join payment:user:user_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), PaymentChannel, "payment:user:user-1")
      assert true
    end
  end

  describe "handle_in" do
    test "process_payment" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:system")

      ref = push(socket, "process_payment", %{
        "payment_id" => "payment-1",
        "amount" => 5000,
        "method" => "card"
      })

      assert_reply ref, :ok, _payload
    end

    test "verify_payment" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:system")

      ref = push(socket, "verify_payment", %{
        "payment_id" => "payment-1"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :status)
    end

    test "process_refund" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:system")

      ref = push(socket, "process_refund", %{
        "payment_id" => "payment-1",
        "reason" => "user_requested"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_payment_history" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:user:user-1")

      ref = push(socket, "get_payment_history", %{
        "user_id" => "user-1",
        "limit" => 10
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "add_payment_method" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:user:user-1")

      ref = push(socket, "add_payment_method", %{
        "user_id" => "user-1",
        "method" => "card",
        "details" => %{"card_number" => "4111111111111111", "expiry" => "12/25"}
      })

      assert_reply ref, :ok, _payload
    end

    test "remove_payment_method" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:user:user-1")

      ref = push(socket, "remove_payment_method", %{
        "user_id" => "user-1",
        "method_id" => "method-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "get_wallet_balance" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:user:user-1")

      ref = push(socket, "get_wallet_balance", %{
        "user_id" => "user-1"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:balance])
    end

    test "add_wallet_credit" do
      {:ok, _, socket} = subscribe_and_join(socket(), PaymentChannel, "payment:user:user-1")

      ref = push(socket, "add_wallet_credit", %{
        "user_id" => "user-1",
        "amount" => 10000
      })

      assert_reply ref, :ok, _payload
    end
  end
end
