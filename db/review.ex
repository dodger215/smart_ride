defmodule SmartBus.DB.Review do
  @moduledoc """
  Review entity for ratings and feedback
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          trip_id: binary(),
          reviewer_id: binary(),
          reviewed_id: binary(),
          role: :passenger | :driver,
          rating: integer(),
          comment: String.t(),
          created_at: DateTime.t()
        }

  defstruct [
    :id,
    :trip_id,
    :reviewer_id,
    :reviewed_id,
    :role,
    :rating,
    :comment,
    :created_at
  ]

  def create(attrs) do
    id = UUID.uuid4()

    review = %__MODULE__{
      id: id,
      trip_id: attrs[:trip_id],
      reviewer_id: attrs[:reviewer_id],
      reviewed_id: attrs[:reviewed_id],
      role: attrs[:role],
      rating: attrs[:rating],
      comment: attrs[:comment],
      created_at: DateTime.utc_now()
    }

    DB.insert(:review, Map.from_struct(review))
  end

  def get_for_user(user_id) do
    DB.query(:review, reviewed_id: user_id)
    |> Enum.map(&struct(__MODULE__, &1.data))
  end

  def average_rating(user_id) do
    reviews = get_for_user(user_id)

    if Enum.empty?(reviews) do
      0.0
    else
      total = Enum.reduce(reviews, 0, &(&1.rating + &2))
      Float.round(total / length(reviews), 1)
    end
  end
end
