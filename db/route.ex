# db/route.ex
defmodule SmartBus.DB.Route do
  @moduledoc """
  Route entity for bus lanes/routes
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          name: String.t(),
          code: String.t(),
          lane: String.t(),
          start_point: {float(), float()},
          end_point: {float(), float()},
          waypoints: list({float(), float()}),
          stops: list(map()),
          distance_km: float(),
          estimated_time_minutes: integer(),
          operating_hours: map(),
          base_fare: float(),
          per_km_fare: float(),
          per_minute_fare: float(),
          min_fare: float(),
          max_fare: float(),
          is_active: boolean(),
          popularity_score: integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :name,
    :code,
    :lane,
    :start_point,
    :end_point,
    :waypoints,
    :stops,
    :distance_km,
    :estimated_time_minutes,
    :operating_hours,
    :base_fare,
    :per_km_fare,
    :per_minute_fare,
    :min_fare,
    :max_fare,
    :is_active,
    :popularity_score,
    :created_at,
    :updated_at
  ]

  @doc """
  Create a new route
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    route = %__MODULE__{
      id: id,
      name: attrs[:name],
      code: attrs[:code],
      lane: attrs[:lane],
      start_point: attrs[:start_point],
      end_point: attrs[:end_point],
      waypoints: attrs[:waypoints] || [],
      stops: attrs[:stops] || [],
      distance_km: attrs[:distance_km],
      estimated_time_minutes: attrs[:estimated_time_minutes],
      operating_hours: attrs[:operating_hours] || %{start: "06:00", end: "22:00"},
      base_fare: attrs[:base_fare] || 50.0,
      per_km_fare: attrs[:per_km_fare] || 10.0,
      per_minute_fare: attrs[:per_minute_fare] || 2.0,
      min_fare: attrs[:min_fare] || 30.0,
      max_fare: attrs[:max_fare] || 500.0,
      is_active: true,
      popularity_score: 0,
      created_at: now,
      updated_at: now
    }

    case DB.insert(:route, Map.from_struct(route)) do
      {:ok, _} -> {:ok, route}
      error -> error
    end
  end

  @doc """
  Get route by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:route, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get route by lane
  """
  @spec get_by_lane(String.t()) :: t() | nil
  def get_by_lane(lane) do
    DB.query(:route, lane: lane, is_active: true)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> List.first()
  end

  @doc """
  Get all active routes
  """
  @spec get_all_active() :: list(t())
  def get_all_active() do
    DB.query(:route, is_active: true)
    |> Enum.map(&struct(__MODULE__, &1.data))
  end

  @doc """
  Update route popularity
  """
  @spec increment_popularity(binary()) :: {:ok, t()} | {:error, String.t()}
  def increment_popularity(id) do
    case get(id) do
      nil -> {:error, "Route not found"}
      route ->
        updated_route = %{
          route
          | popularity_score: route.popularity_score + 1,
            updated_at: DateTime.utc_now()
        }

        DB.update(:route, id, Map.from_struct(updated_route))
        {:ok, updated_route}
    end
  end

  @doc """
  Calculate fare for a route
  """
  @spec calculate_fare(t(), float(), integer()) :: float()
  def calculate_fare(route, distance_km, time_minutes) do
    fare = route.base_fare +
           (distance_km * route.per_km_fare) +
           (time_minutes * route.per_minute_fare)

    fare
    |> max(route.min_fare)
    |> min(route.max_fare)
    |> Float.round(2)
  end

  @doc """
  Find nearest stop
  """
  @spec find_nearest_stop(t(), {float(), float()}) :: map() | nil
  def find_nearest_stop(route, location) do
    route.stops
    |> Enum.min_by(fn stop ->
      distance(location, stop.location)
    end)
  end

  defp distance({lat1, lng1}, {lat2, lng2}) do
    :math.sqrt(:math.pow(lat2 - lat1, 2) + :math.pow(lng2 - lng1, 2))
  end
end
