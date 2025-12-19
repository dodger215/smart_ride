defmodule SmartBusWeb.DynamicPricingChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.DynamicPricingChannel

  describe "join" do
    test "join pricing:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), DynamicPricingChannel, "pricing:system")
      assert true
    end

    test "join pricing:lane:lane_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), DynamicPricingChannel, "pricing:lane:lane-1")
      assert true
    end
  end

  describe "handle_in" do
    test "calculate_surge" do
      {:ok, _, socket} = subscribe_and_join(socket(), DynamicPricingChannel, "pricing:system")

      ref = push(socket, "calculate_surge", %{
        "lane" => "lane-1",
        "demand" => 100,
        "supply" => 20,
        "conditions" => "peak_hour"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:multiplier])
    end

    test "get_base_price" do
      {:ok, _, socket} = subscribe_and_join(socket(), DynamicPricingChannel, "pricing:lane:lane-1")

      ref = push(socket, "get_base_price", %{
        "lane" => "lane-1"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:price])
    end

    test "validate_discount_code" do
      {:ok, _, socket} = subscribe_and_join(socket(), DynamicPricingChannel, "pricing:system")

      ref = push(socket, "validate_discount_code", %{
        "code" => "DISCOUNT10"
      })

      assert_reply ref, :ok, _payload
    end

    test "apply_promotional_pricing" do
      {:ok, _, socket} = subscribe_and_join(socket(), DynamicPricingChannel, "pricing:system")

      ref = push(socket, "apply_promotional_pricing", %{
        "passenger_id" => "pass-1",
        "promotion_id" => "promo-1"
      })

      assert_reply ref, :ok, _payload
    end

    test "update_pricing_rules" do
      {:ok, _, socket} = subscribe_and_join(socket(), DynamicPricingChannel, "pricing:system")

      ref = push(socket, "update_pricing_rules", %{
        "lane" => "lane-1",
        "new_rules" => %{
          "base_price" => 50,
          "surge_multiplier" => 2.5
        }
      })

      assert_reply ref, :ok, _payload
    end
  end
end
