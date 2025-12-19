defmodule SmartBusWeb.AuthChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.AuthChannel

  describe "join" do
    test "join auth:user topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), AuthChannel, "auth:user")
      assert true
    end

    test "join auth:driver topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), AuthChannel, "auth:driver")
      assert true
    end

    test "join auth:admin topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), AuthChannel, "auth:admin")
      assert true
    end
  end

  describe "handle_in" do
    test "register user" do
      {:ok, _, socket} = subscribe_and_join(socket(), AuthChannel, "auth:user")

      ref = push(socket, "register", %{
        "phone" => "1234567890",
        "email" => "test@example.com",
        "password" => "password123",
        "role" => "passenger",
        "full_name" => "Test User"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :message)
      assert Map.has_key?(payload, :user_id)
    end

    test "register driver" do
      {:ok, _, socket} = subscribe_and_join(socket(), AuthChannel, "auth:driver")

      ref = push(socket, "register", %{
        "phone" => "9876543210",
        "email" => "driver@example.com",
        "password" => "password123",
        "role" => "driver",
        "full_name" => "Test Driver",
        "driver_license" => "DL123456",
        "license_expiry" => "2025-12-31"
      })

      assert_reply ref, :ok, payload
      assert payload.message == "Registration successful. OTP sent."
    end

    test "verify_otp" do
      {:ok, _, socket} = subscribe_and_join(socket(), AuthChannel, "auth:user")

      ref = push(socket, "verify_otp", %{
        "user_id" => "test-user-1",
        "otp" => "123456"
      })

      assert_reply ref, :ok, _payload
    end

    test "login with phone and password" do
      {:ok, _, socket} = subscribe_and_join(socket(), AuthChannel, "auth:user")

      ref = push(socket, "login", %{
        "phone" => "1234567890",
        "password" => "password123"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :token)
      assert Map.has_key?(payload, :user)
    end

    test "logout" do
      {:ok, _, socket} = subscribe_and_join(socket(), AuthChannel, "auth:user")

      ref = push(socket, "logout", %{})

      assert_reply ref, :ok, payload
      assert payload.message == "Logged out successfully"
    end

    test "reset_password" do
      {:ok, _, socket} = subscribe_and_join(socket(), AuthChannel, "auth:user")

      ref = push(socket, "reset_password", %{
        "phone" => "1234567890"
      })

      assert_reply ref, :ok, payload
      assert payload.message == "Reset link sent"
    end

    test "verify_reset_token" do
      {:ok, _, socket} = subscribe_and_join(socket(), AuthChannel, "auth:user")

      ref = push(socket, "verify_reset_token", %{
        "token" => "reset-token-123",
        "new_password" => "newpassword123"
      })

      assert_reply ref, :ok, payload
      assert payload.message == "Password reset successful"
    end
  end
end
