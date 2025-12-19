defmodule SmartBusWeb.IntegrationChannel do
  use Phoenix.Channel

  def join("integration:system", _params, socket), do: {:ok, socket}

  def handle_in("maps_api_call", %{"action" => action, "params" => params}, socket) do
    result = call_maps_api(action, params)
    {:reply, {:ok, %{result: result}}, socket}
  end

  def handle_in("payment_gateway", %{"gateway" => gateway, "action" => action, "data" => data}, socket) do
    result = process_payment_gateway(gateway, action, data)
    {:reply, {:ok, %{result: result}}, socket}
  end

  def handle_in("send_sms", %{"phone" => phone, "message" => message}, socket) do
    result = send_sms_integration(phone, message)
    {:reply, {:ok, %{result: result}}, socket}
  end

  def handle_in("push_notification", %{"user_id" => user_id, "title" => title, "body" => body}, socket) do
    result = send_push_notification(user_id, title, body)
    {:reply, {:ok, %{result: result}}, socket}
  end

  def handle_in("webhook_event", %{"source" => source, "event" => event, "data" => data}, socket) do
    process_webhook(source, event, data)
    {:reply, {:ok, %{processed: true}}, socket}
  end

  defp call_maps_api(action, params), do: %{status: "mock"}
  defp process_payment_gateway(gateway, action, data), do: %{status: "mock"}
  defp send_sms_integration(phone, message), do: %{sent: true}
  defp send_push_notification(user_id, title, body), do: %{sent: true}
  defp process_webhook(source, event, data), do: :ok
end
