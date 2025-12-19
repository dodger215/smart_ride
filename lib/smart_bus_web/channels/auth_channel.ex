# lib/smart_bus_web/channels/auth_channel.ex
defmodule SmartBusWeb.AuthChannel do
  use Phoenix.Channel
  alias SmartBus.DB.User
  alias SmartBus.DB.Driver

  def join("auth:user", _params, socket) do
    {:ok, socket}
  end

  def join("auth:driver", _params, socket) do
    {:ok, socket}
  end

  def join("auth:admin", _params, socket) do
    {:ok, socket}
  end

  def handle_in("register", payload, socket) do
    user_data = %{
      phone: payload["phone"],
      email: payload["email"],
      password: payload["password"],
      role: String.to_atom(payload["role"] || "passenger"),
      full_name: payload["full_name"]
    }

    case User.create(user_data) do
      {:ok, user} ->
        # If registering as driver, create driver profile
        if user.role == :driver do
          Driver.create(%{
            user_id: user.id,
            driver_license: payload["driver_license"],
            license_expiry: payload["license_expiry"]
          })
        end

        broadcast(socket, "otp_sent", %{phone: user.phone})
        {:reply, {:ok, %{message: "Registration successful. OTP sent.", user_id: user.id}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("verify_otp", %{"user_id" => user_id, "otp" => otp}, socket) do
    case User.verify_otp(user_id, otp) do
      {:ok, user} ->
        token = generate_token(user.id)
        {:reply, {:ok, %{token: token, user: user}}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("login", %{"phone" => phone, "password" => password}, socket) do
    case User.authenticate(phone, password) do
      {:ok, user} ->
        token = generate_token(user.id)

        # Get additional info based on role
        extra_data = case user.role do
          :driver ->
            case Driver.get_by_user(user.id) do
              nil -> %{}
              driver -> %{driver_id: driver.id, driver_status: driver.status}
            end
          _ -> %{}
        end

        {:reply, {:ok, %{token: token, user: user} |> Map.merge(extra_data)}, socket}
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("logout", _payload, socket) do
    broadcast(socket, "user_logged_out", %{timestamp: DateTime.utc_now()})
    {:reply, {:ok, %{message: "Logged out successfully"}}, socket}
  end

  def handle_in("reset_password", %{"phone" => phone}, socket) do
    case User.find_by_phone(phone) do
      nil ->
        {:reply, {:error, %{reason: "User not found"}}, socket}
      user ->
        # Generate reset token (in production, use proper token generation)
        reset_token = generate_reset_token()
        # Send reset link via SMS/email
        send_reset_link(user.phone, reset_token)
        {:reply, {:ok, %{message: "Reset link sent"}}, socket}
    end
  end

  def handle_in("verify_reset_token", %{"token" => token, "new_password" => password}, socket) do
    # Verify token and update password
    # Implementation depends on token storage
    {:reply, {:ok, %{message: "Password reset successful"}}, socket}
  end

  defp generate_token(user_id) do
    payload = %{
      user_id: user_id,
      exp: DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.to_unix()
    }

    # In production, use JWT or similar
    :crypto.hash(:sha256, Jason.encode!(payload))
    |> Base.encode64()
  end

  defp generate_reset_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
    |> String.replace(~r/[+\/]/, "")
    |> String.slice(0, 32)
  end

  defp send_reset_link(phone, token) do
    # Integrate with SMS service
    IO.puts("Reset link for #{phone}: #{token}")
  end
end
