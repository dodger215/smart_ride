defmodule SmartBusWeb.DynamicPricingChannel do
  use Phoenix.Channel
  alias SmartBus.DB.FareConfig

  def join("dynamic_pricing:lane:" <> lane, _params, socket) do
    socket = assign(socket, :lane, lane)
    {:ok, socket}
  end

  def handle_in("calculate_surge", %{
    "demand" => demand,
    "supply" => supply,
    "conditions" => conditions
  }, socket) do
    lane = socket.assigns.lane
    surge = calculate_surge_multiplier(demand, supply, conditions)

    {:reply, {:ok, %{
      lane: lane,
      surge_multiplier: surge,
      base_price: get_base_price(lane),
      final_price: get_base_price(lane) * surge
    }}, socket}
  end

  def handle_in("update_pricing", %{"config" => config}, socket) do
    lane = socket.assigns.lane
    {:ok, fare_config} = FareConfig.update_for_lane(lane, config)
    {:reply, {:ok, %{config: fare_config}}, socket}
  end

  def handle_in("apply_discounts", %{"discount_code" => code, "fare" => fare}, socket) do
    discount = validate_discount_code(code)
    final_fare = apply_discount(fare, discount)

    {:reply, {:ok, %{
      original_fare: fare,
      discount: discount,
      final_fare: final_fare,
      discount_code: code
    }}, socket}
  end

  defp calculate_surge_multiplier(demand, supply, conditions), do: 1.0
  defp get_base_price(lane), do: 50.0
  defp validate_discount_code(code), do: %{percentage: 10, valid: true}
  defp apply_discount(fare, discount), do: fare * (1 - discount.percentage / 100)
end
