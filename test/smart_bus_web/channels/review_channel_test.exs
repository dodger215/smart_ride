defmodule SmartBusWeb.ReviewChannelTest do
  use SmartBusWeb.ChannelCase
  alias SmartBusWeb.ReviewChannel

  describe "join" do
    test "join review:trip:trip_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), ReviewChannel, "review:trip:trip-1")
      assert true
    end

    test "join review:driver:driver_id topic" do
      {:ok, _, _socket} = subscribe_and_join(socket(), ReviewChannel, "review:driver:driver-1")
      assert true
    end
  end

  describe "handle_in" do
    test "submit_driver_review" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReviewChannel, "review:driver:driver-1")

      ref = push(socket, "submit_driver_review", %{
        "trip_id" => "trip-1",
        "driver_id" => "driver-1",
        "rating" => 5,
        "comment" => "Excellent service"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :review_id)
    end

    test "submit_passenger_review" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReviewChannel, "review:trip:trip-1")

      ref = push(socket, "submit_passenger_review", %{
        "trip_id" => "trip-1",
        "passenger_id" => "pass-1",
        "rating" => 4,
        "comment" => "Good ride"
      })

      assert_reply ref, :ok, payload
      assert Map.has_key?(payload, :review_id)
    end

    test "get_driver_reviews" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReviewChannel, "review:driver:driver-1")

      ref = push(socket, "get_driver_reviews", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, payload
      assert is_list(payload)
    end

    test "get_average_rating" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReviewChannel, "review:driver:driver-1")

      ref = push(socket, "get_average_rating", %{
        "driver_id" => "driver-1"
      })

      assert_reply ref, :ok, payload
      assert is_number(payload[:average_rating])
    end

    test "flag_review" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReviewChannel, "review:trip:trip-1")

      ref = push(socket, "flag_review", %{
        "review_id" => "review-1",
        "reason" => "inappropriate_content"
      })

      assert_reply ref, :ok, _payload
    end

    test "delete_review" do
      {:ok, _, socket} = subscribe_and_join(socket(), ReviewChannel, "review:trip:trip-1")

      ref = push(socket, "delete_review", %{
        "review_id" => "review-1"
      })

      assert_reply ref, :ok, _payload
    end
  end
end
