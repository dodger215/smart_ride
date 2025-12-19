defmodule SmartBusWeb.ReportsChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.ReportsChannel

  describe "join" do
    test "join reports:admin topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")
      assert true
    end

    test "join reports:driver topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), ReportsChannel, "reports:driver")
      assert true
    end
  end

  describe "handle_in" do
    test "generate_revenue_report" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")

      ref = push(socket, "generate_revenue_report", %{
        "period" => "monthly",
        "date_range" => "2025-01-01:2025-01-31"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :report)
    end

    test "generate_trips_report" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")

      ref = push(socket, "generate_trips_report", %{
        "period" => "weekly",
        "date_range" => "2025-01-01:2025-01-31"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :report)
    end

    test "analyze_payment_methods" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")

      ref = push(socket, "analyze_payment_methods", %{})

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "generate_trip_statistics" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")

      ref = push(socket, "generate_trip_statistics", %{
        "lane" => "lane-1",
        "period" => "monthly"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :statistics)
    end

    test "get_popular_routes" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")

      ref = push(socket, "get_popular_routes", %{
        "limit" => 10
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "analyze_revenue" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")

      ref = push(socket, "analyze_revenue", %{
        "period" => "quarterly",
        "breakdown_by" => "lane"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :revenue_data)
    end

    test "generate_export_report" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:admin")

      ref = push(socket, "generate_export_report", %{
        "format" => "csv",
        "params" => %{"type" => "trips"}
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :file_url)
    end

    test "driver_earnings_report" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReportsChannel, "reports:driver")

      ref = push(socket, "driver_earnings_report", %{
        "driver_id" => "driver-1",
        "period" => "monthly"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :earnings)
    end
  end
end
