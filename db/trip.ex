defmodule SmartBus.DB.Trip do
  @moduledoc """
  Trip entity representing a passenger journey
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          passenger_id: binary(),
          driver_id: binary(),
          vehicle_id: binary(),
          route_id: binary(),
          request_id: binary(),
          pickup_location: {float(), float()},
          dropoff_location: {float(), float()},
          pickup_stop: map() | nil,
          dropoff_stop: map() | nil,
          scheduled_time: DateTime.t() | nil,
          actual_pickup_time: DateTime.t() | nil,
          actual_dropoff_time: DateTime.t() | nil,
          seats_booked: integer(),
          fare_amount: float(),
          distance_km: float(),
          estimated_time_minutes: integer(),
          actual_time_minutes: integer() | nil,
          status: :requested | :accepted | :boarding | :in_progress | :completed | :cancelled | :no_show,
          payment_status: :pending | :paid | :refunded | :failed,
          payment_method: :cash | :mobile_money | :card,
          payment_id: binary() | nil,
          cancellation_reason: String.t() | nil,
          cancelled_by: :passenger | :driver | :system | nil,
          passenger_rating: integer() | nil,
          driver_rating: integer() | nil,
          passenger_review: String.t() | nil,
          driver_review: String.t() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :passenger_id,
    :driver_id,
    :vehicle_id,
    :route_id,
    :request_id,
    :pickup_location,
    :dropoff_location,
    :pickup_stop,
    :dropoff_stop,
    :scheduled_time,
    :actual_pickup_time,
    :actual_dropoff_time,
    :seats_booked,
    :fare_amount,
    :distance_km,
    :estimated_time_minutes,
    :actual_time_minutes,
    :status,
    :payment_status,
    :payment_method,
    :payment_id,
    :cancellation_reason,
    :cancelled_by,
    :passenger_rating,
    :driver_rating,
    :passenger_review,
    :driver_review,
    :created_at,
    :updated_at
  ]

  @doc """
  Create a new trip
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    trip = %__MODULE__{
      id: id,
      passenger_id: attrs[:passenger_id],
      driver_id: attrs[:driver_id],
      vehicle_id: attrs[:vehicle_id],
      route_id: attrs[:route_id],
      request_id: attrs[:request_id],
      pickup_location: attrs[:pickup_location],
      dropoff_location: attrs[:dropoff_location],
      pickup_stop: attrs[:pickup_stop],
      dropoff_stop: attrs[:dropoff_stop],
      scheduled_time: attrs[:scheduled_time],
      seats_booked: attrs[:seats_booked] || 1,
      fare_amount: attrs[:fare_amount] || 0.0,
      distance_km: attrs[:distance_km] || 0.0,
      estimated_time_minutes: attrs[:estimated_time_minutes] || 0,
      status: :requested,
      payment_status: :pending,
      payment_method: attrs[:payment_method] || :cash,
      created_at: now,
      updated_at: now
    }

    case DB.insert(:trip, Map.from_struct(trip)) do
      {:ok, _} -> {:ok, trip}
      error -> error
    end
  end

  @doc """
  Get trip by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:trip, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get trips by passenger ID
  """
  @spec get_by_passenger(binary(), keyword()) :: list(t())
  def get_by_passenger(passenger_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status)

    query = [passenger_id: passenger_id]
    query = if status, do: Keyword.put(query, :status, status), else: query

    DB.query(:trip, query)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Get trips by driver ID
  """
  @spec get_by_driver(binary(), keyword()) :: list(t())
  def get_by_driver(driver_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status)

    query = [driver_id: driver_id]
    query = if status, do: Keyword.put(query, :status, status), else: query

    DB.query(:trip, query)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Update trip status
  """
  @spec update_status(binary(), atom()) :: {:ok, t()} | {:error, String.t()}
  def update_status(id, status) when status in [
    :accepted, :boarding, :in_progress, :completed, :cancelled, :no_show
  ] do
    case get(id) do
      nil -> {:error, "Trip not found"}
      trip ->
        updated_trip = %{
          trip
          | status: status,
            updated_at: DateTime.utc_now()
        }

        # Set timestamps based on status
        updated_trip = case status do
          :boarding -> %{updated_trip | actual_pickup_time: DateTime.utc_now()}
          :completed -> %{updated_trip |
            actual_dropoff_time: DateTime.utc_now(),
            actual_time_minutes: calculate_actual_time(trip)
          }
          _ -> updated_trip
        end

        DB.update(:trip, id, Map.from_struct(updated_trip))
        {:ok, updated_trip}
    end
  end

  @doc """
  Cancel trip
  """
  @spec cancel(binary(), String.t(), atom()) :: {:ok, t()} | {:error, String.t()}
  def cancel(id, reason, cancelled_by) when cancelled_by in [:passenger, :driver, :system] do
    case get(id) do
      nil -> {:error, "Trip not found"}
      trip ->
        updated_trip = %{
          trip
          | status: :cancelled,
            cancellation_reason: reason,
            cancelled_by: cancelled_by,
            updated_at: DateTime.utc_now()
        }

        DB.update(:trip, id, Map.from_struct(updated_trip))
        {:ok, updated_trip}
    end
  end

  @doc """
  Update payment status
  """
  @spec update_payment(binary(), atom(), binary() | nil) :: {:ok, t()} | {:error, String.t()}
  def update_payment(id, status, payment_id \\ nil) when status in [:paid, :refunded, :failed] do
    case get(id) do
      nil -> {:error, "Trip not found"}
      trip ->
        updated_trip = %{
          trip
          | payment_status: status,
            payment_id: payment_id || trip.payment_id,
            updated_at: DateTime.utc_now()
        }

        DB.update(:trip, id, Map.from_struct(updated_trip))
        {:ok, updated_trip}
    end
  end

  @doc """
  Add passenger rating
  """
  @spec rate_passenger(binary(), integer(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def rate_passenger(id, rating, review \\ nil) when rating in 1..5 do
    case get(id) do
      nil -> {:error, "Trip not found"}
      trip ->
        updated_trip = %{
          trip
          | passenger_rating: rating,
            passenger_review: review,
            updated_at: DateTime.utc_now()
        }

        DB.update(:trip, id, Map.from_struct(updated_trip))
        {:ok, updated_trip}
    end
  end

  @doc """
  Add driver rating
  """
  @spec rate_driver(binary(), integer(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def rate_driver(id, rating, review \\ nil) when rating in 1..5 do
    case get(id) do
      nil -> {:error, "Trip not found"}
      trip ->
        updated_trip = %{
          trip
          | driver_rating: rating,
            driver_review: review,
            updated_at: DateTime.utc_now()
        }

        DB.update(:trip, id, Map.from_struct(updated_trip))
        {:ok, updated_trip}
    end
  end

  @doc """
  Get active trips for driver
  """
  @spec get_active_driver_trips(binary()) :: list(t())
  def get_active_driver_trips(driver_id) do
    DB.query(:trip, driver_id: driver_id, status: [:boarding, :in_progress])
    |> Enum.map(&struct(__MODULE__, &1.data))
  end

  @doc """
  Get active trips for passenger
  """
  @spec get_active_passenger_trips(binary()) :: list(t())
  def get_active_passenger_trips(passenger_id) do
    DB.query(:trip, passenger_id: passenger_id, status: [:boarding, :in_progress])
    |> Enum.map(&struct(__MODULE__, &1.data))
  end

  defp calculate_actual_time(trip) do
    if trip.actual_pickup_time && trip.actual_dropoff_time do
      DateTime.diff(trip.actual_dropoff_time, trip.actual_pickup_time, :second)
      |> div(60)
    else
      nil
    end
  end
end
