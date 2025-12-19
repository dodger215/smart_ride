defmodule SmartBusWeb.ReviewChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Review
  alias SmartBus.DB.Trip

  def join("review:trip:" <> trip_id, _params, socket) do
    case Trip.get(trip_id) do
      nil -> {:error, %{reason: "Trip not found"}}
      _ ->
        socket = assign(socket, :trip_id, trip_id)
        {:ok, socket}
    end
  end

  def join("review:user:" <> user_id, _params, socket) do
    socket = assign(socket, :user_id, user_id)
    {:ok, socket}
  end

  def handle_in("submit_review", %{
    "trip_id" => trip_id,
    "rating" => rating,
    "comment" => comment,
    "reviewer_role" => reviewer_role
  }, socket) do
    user_id = socket.assigns.user_id

    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        reviewed_id = case reviewer_role do
          "passenger" -> trip.driver_id
          "driver" -> trip.passenger_id
          _ -> nil
        end

        if reviewed_id do
          review_data = %{
            trip_id: trip_id,
            reviewer_id: user_id,
            reviewed_id: reviewed_id,
            role: String.to_atom(reviewer_role),
            rating: rating,
            comment: comment
          }

          case Review.create(review_data) do
            {:ok, review} ->
              # Update trip with rating
              update_trip_rating(trip, reviewer_role, rating, comment)

              # Notify reviewed user
              notify_reviewed_user(reviewed_id, review)

              {:reply, {:ok, %{
                review_id: review.id,
                message: "Review submitted successfully"
              }}, socket}
            {:error, reason} ->
              {:reply, {:error, %{reason: reason}}, socket}
          end
        else
          {:reply, {:error, %{reason: "Invalid reviewer role"}}, socket}
        end
    end
  end

  def handle_in("rate_driver", %{
    "trip_id" => trip_id,
    "rating" => rating,
    "comment" => comment
  }, socket) do
    user_id = socket.assigns.user_id

    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        # Submit driver review
        Trip.rate_driver(trip_id, rating, comment)

        # Create review record
        review_data = %{
          trip_id: trip_id,
          reviewer_id: user_id,
          reviewed_id: trip.driver_id,
          role: :passenger,
          rating: rating,
          comment: comment
        }

        Review.create(review_data)

        {:reply, {:ok, %{message: "Driver rated successfully"}}, socket}
    end
  end

  def handle_in("rate_passenger", %{
    "trip_id" => trip_id,
    "rating" => rating,
    "comment" => comment
  }, socket) do
    user_id = socket.assigns.user_id

    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        # Submit passenger review
        Trip.rate_passenger(trip_id, rating, comment)

        # Create review record
        review_data = %{
          trip_id: trip_id,
          reviewer_id: user_id,
          reviewed_id: trip.passenger_id,
          role: :driver,
          rating: rating,
          comment: comment
        }

        Review.create(review_data)

        {:reply, {:ok, %{message: "Passenger rated successfully"}}, socket}
    end
  end

  def handle_in("view_ratings", %{"user_id" => target_user_id}, socket) do
    reviews = Review.get_for_user(target_user_id)
    average_rating = Review.average_rating(target_user_id)

    {:reply, {:ok, %{
      reviews: reviews,
      average_rating: average_rating,
      total_reviews: length(reviews)
    }}, socket}
  end

  def handle_in("get_trip_reviews", %{"trip_id" => trip_id}, socket) do
    # Get both driver and passenger reviews for trip
    case Trip.get(trip_id) do
      nil -> {:reply, {:error, %{reason: "Trip not found"}}, socket}
      trip ->
        reviews = %{
          driver_review: %{
            rating: trip.driver_rating,
            comment: trip.driver_review
          },
          passenger_review: %{
            rating: trip.passenger_rating,
            comment: trip.passenger_review
          }
        }

        {:reply, {:ok, %{reviews: reviews}}, socket}
    end
  end

  def handle_in("report_review", %{
    "review_id" => review_id,
    "reason" => reason
  }, socket) do
    # Report inappropriate review
    # This would flag the review for admin review

    {:reply, {:ok, %{
      message: "Review reported for moderation",
      review_id: review_id
    }}, socket}
  end

  def handle_in("get_review_stats", %{"user_id" => user_id}, socket) do
    reviews = Review.get_for_user(user_id)

    stats = %{
      total_reviews: length(reviews),
      average_rating: Review.average_rating(user_id),
      rating_distribution: calculate_rating_distribution(reviews),
      recent_reviews: Enum.take(reviews, 5)
    }

    {:reply, {:ok, %{stats: stats}}, socket}
  end

  defp update_trip_rating(trip, reviewer_role, rating, comment) do
    case reviewer_role do
      "passenger" ->
        Trip.rate_driver(trip.id, rating, comment)
      "driver" ->
        Trip.rate_passenger(trip.id, rating, comment)
    end
  end

  defp notify_reviewed_user(user_id, review) do
    # Send notification about new review
    SmartBusWeb.Endpoint.broadcast("user:#{user_id}", "new_review", %{
      review_id: review.id,
      rating: review.rating,
      reviewer_role: review.role,
      timestamp: DateTime.utc_now()
    })
  end

  defp calculate_rating_distribution(reviews) do
    Enum.reduce(reviews, %{1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0}, fn review, acc ->
      Map.update(acc, review.rating, 1, &(&1 + 1))
    end)
  end
end
