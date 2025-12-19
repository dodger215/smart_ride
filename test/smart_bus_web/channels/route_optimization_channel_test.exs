defmodule SmartBusWeb.RouteOptimizationChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.RouteOptimizationChannel

  describe "join" do
    test "join route_optimization:system topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), RouteOptimizationChannel, "route_optimization:system")
      assert true
    end

    test "join route_optimization:lane:lane_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), RouteOptimizationChannel, "route_optimization:lane:lane-1")
      assert true
    end
  end

  describe "handle_in" do
    test "analyze_demand_patterns" do
      {:ok, _, socket} = subscribe_and_join(socket(), RouteOptimizationChannel, "route_optimization:system")

      ref = push(socket, "analyze_demand_patterns", %{
        "area" => "downtown",
        "time_range" => "morning_rush"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :patterns)
    end

    test "suggest_optimal_routes" do
      {:ok, _, socket} = subscribe_and_join(socket(), RouteOptimizationChannel, "route_optimization:system")

      ref = push(socket, "suggest_optimal_routes", %{
        "points" => [
          %{"lat" => 40.7128, "lng" => -74.0060},
          %{"lat" => 40.7580, "lng" => -73.9855}
        ],
        "constraints" => %{"max_detour" => 10}
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "optimize_schedule" do
      {:ok, _, socket} = subscribe_and_join(socket(), RouteOptimizationChannel, "route_optimization:lane:lane-1")

      ref = push(socket, "optimize_schedule", %{
        "lane" => "lane-1",
        "demand" => 150
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :optimized_schedule)
    end

    test "predict_congestion" do
      {:ok, _, socket} = subscribe_and_join(socket(), RouteOptimizationChannel, "route_optimization:system")

      ref = push(socket, "predict_congestion", %{
        "route" => "route-1"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:congestion_level])
    end

    test "get_alternative_routes" do
      {:ok, _, socket} = subscribe_and_join(socket(), RouteOptimizationChannel, "route_optimization:system")

      ref = push(socket, "get_alternative_routes", %{
        "origin" => %{"lat" => 40.7128, "lng" => -74.0060},
        "destination" => %{"lat" => 40.7580, "lng" => -73.9855}
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end
  end
end
