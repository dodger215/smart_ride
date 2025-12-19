defmodule SmartBusWeb.OfflineOperationsChannel do
  use Phoenix.Channel

  def join("offline_operations:device:" <> device_id, _params, socket) do
    socket = assign(socket, :device_id, device_id)
    {:ok, socket}
  end

  def handle_in("cache_data", %{"data_type" => type, "data" => data}, socket) do
    cache_result = cache_offline_data(socket.assigns.device_id, type, data)
    {:reply, {:ok, %{cached: cache_result}}, socket}
  end

  def handle_in("sync_offline_tickets", %{"tickets" => tickets}, socket) do
    sync_result = sync_offline_tickets(tickets)
    {:reply, {:ok, %{synced: sync_result}}, socket}
  end

  def handle_in("validate_offline", %{"ticket_id" => ticket_id, "code" => code}, socket) do
    validation = validate_offline_ticket(ticket_id, code)
    {:reply, {:ok, %{valid: validation.valid, ticket: validation.ticket}}, socket}
  end

  def handle_in("get_cached_data", %{"data_type" => type}, socket) do
    data = get_cached_data(socket.assigns.device_id, type)
    {:reply, {:ok, %{data: data}}, socket}
  end

  defp cache_offline_data(device_id, type, data), do: true
  defp sync_offline_tickets(tickets), do: %{success: true, count: length(tickets)}
  defp validate_offline_ticket(ticket_id, code), do: %{valid: true, ticket: %{}}
  defp get_cached_data(device_id, type), do: []
end
