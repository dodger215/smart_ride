defmodule SmartBus.DB.Lane do
  @moduledoc """
  Lane entity for managing bus lanes/routes
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          code: String.t(),
          name: String.t(),
          description: String.t(),
          start_location: {float(), float()},
          end_location: {float(), float()},
          path_coordinates: list({float(), float()}),
          total_distance_km: float(),
          estimated_travel_time_minutes: integer(),
          operating_hours: map(),
          peak_hours: list(map()),
          bus_stops: list(map()),
          interchange_points: list(map()),
          restrictions: list(String.t()),
          status: :active | :inactive | :maintenance,
          capacity_per_hour: integer(),
          current_demand: integer(),
          average_wait_time: integer(),
          popularity_rank: integer(),
          color_code: String.t(),
          icon_url: String.t() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :code,
    :name,
    :description,
    :start_location,
    :end_location,
    :path_coordinates,
    :total_distance_km,
    :estimated_travel_time_minutes,
    :operating_hours,
    :peak_hours,
    :bus_stops,
    :interchange_points,
    :restrictions,
    :status,
    :capacity_per_hour,
    :current_demand,
    :average_wait_time,
    :popularity_rank,
    :color_code,
    :icon_url,
    :created_at,
    :updated_at
  ]

  @doc """
  Create a new lane
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    lane = %__MODULE__{
      id: id,
      code: attrs[:code],
      name: attrs[:name],
      description: attrs[:description] || "",
      start_location: attrs[:start_location],
      end_location: attrs[:end_location],
      path_coordinates: attrs[:path_coordinates] || [],
      total_distance_km: attrs[:total_distance_km] || 0.0,
      estimated_travel_time_minutes: attrs[:estimated_travel_time_minutes] || 0,
      operating_hours: attrs[:operating_hours] || %{
        weekdays: %{start: "06:00", end: "22:00"},
        weekends: %{start: "07:00", end: "23:00"}
      },
      peak_hours: attrs[:peak_hours] || [
        %{start: "07:00", end: "09:00", type: :morning_peak},
        %{start: "17:00", end: "19:00", type: :evening_peak}
      ],
      bus_stops: attrs[:bus_stops] || [],
      interchange_points: attrs[:interchange_points] || [],
      restrictions: attrs[:restrictions] || [],
      status: :active,
      capacity_per_hour: attrs[:capacity_per_hour] || 100,
      current_demand: 0,
      average_wait_time: 5, # minutes
      popularity_rank: 0,
      color_code: attrs[:color_code] || generate_color_code(),
      icon_url: attrs[:icon_url],
      created_at: now,
      updated_at: now
    }

    case DB.insert(:lane, Map.from_struct(lane)) do
      {:ok, _} -> {:ok, lane}
      error -> error
    end
  end

  @doc """
  Get lane by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:lane, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get lane by code
  """
  @spec get_by_code(String.t()) :: t() | nil
  def get_by_code(code) do
    DB.query(:lane, code: code)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> List.first()
  end

  @doc """
  Get all active lanes
  """
  @spec get_all_active() :: list(t())
  def get_all_active() do
    DB.query(:lane, status: :active)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(& &1.popularity_rank, :desc)
  end

  @doc """
  Update lane status
  """
  @spec update_status(binary(), atom()) :: {:ok, t()} | {:error, String.t()}
  def update_status(id, status) when status in [:active, :inactive, :maintenance] do
    case get(id) do
      nil -> {:error, "Lane not found"}
      lane ->
        updated_lane = %{lane | status: status, updated_at: DateTime.utc_now()}
        DB.update(:lane, id, Map.from_struct(updated_lane))
        {:ok, updated_lane}
    end
  end

  @doc """
  Update lane demand
  """
  @spec update_demand(binary(), integer()) :: {:ok, t()} | {:error, String.t()}
  def update_demand(id, demand_change) do
    case get(id) do
      nil -> {:error, "Lane not found"}
      lane ->
        new_demand = max(0, lane.current_demand + demand_change)
        updated_lane = %{
          lane
          | current_demand: new_demand,
            average_wait_time: calculate_wait_time(new_demand, lane.capacity_per_hour),
            updated_at: DateTime.utc_now()
        }

        DB.update(:lane, id, Map.from_struct(updated_lane))
        {:ok, updated_lane}
    end
  end

  @doc """
  Increment lane popularity
  """
  @spec increment_popularity(binary()) :: {:ok, t()} | {:error, String.t()}
  def increment_popularity(id) do
    case get(id) do
      nil -> {:error, "Lane not found"}
      lane ->
        updated_lane = %{
          lane
          | popularity_rank: lane.popularity_rank + 1,
            updated_at: DateTime.utc_now()
        }

        DB.update(:lane, id, Map.from_struct(updated_lane))
        {:ok, updated_lane}
    end
  end

  @doc """
  Add bus stop to lane
  """
  @spec add_bus_stop(binary(), map()) :: {:ok, t()} | {:error, String.t()}
  def add_bus_stop(id, bus_stop) do
    case get(id) do
      nil -> {:error, "Lane not found"}
      lane ->
        stop_with_id = Map.put(bus_stop, :id, UUID.uuid4())
        updated_stops = [stop_with_id | lane.bus_stops]
        updated_lane = %{lane | bus_stops: updated_stops, updated_at: DateTime.utc_now()}

        DB.update(:lane, id, Map.from_struct(updated_lane))
        {:ok, updated_lane}
    end
  end

  @doc """
  Remove bus stop from lane
  """
  @spec remove_bus_stop(binary(), binary()) :: {:ok, t()} | {:error, String.t()}
  def remove_bus_stop(lane_id, stop_id) do
    case get(lane_id) do
      nil -> {:error, "Lane not found"}
      lane ->
        updated_stops = Enum.reject(lane.bus_stops, &(&1.id == stop_id))
        updated_lane = %{lane | bus_stops: updated_stops, updated_at: DateTime.utc_now()}

        DB.update(:lane, lane_id, Map.from_struct(updated_lane))
        {:ok, updated_lane}
    end
  end

  @doc """
  Find nearest bus stop on lane
  """
  @spec find_nearest_stop(t(), {float(), float()}) :: map() | nil
  def find_nearest_stop(lane, location) do
    lane.bus_stops
    |> Enum.min_by(fn stop ->
      calculate_distance(location, stop.location)
    end)
  end

  @doc """
  Check if lane is operating now
  """
  @spec is_operating_now?(t(), DateTime.t()) :: boolean()
  def is_operating_now?(lane, datetime \\ DateTime.utc_now()) do
    day_of_week = Date.day_of_week(datetime.date)

    operating_schedule = if day_of_week in [6, 7] do
      lane.operating_hours.weekends
    else
      lane.operating_hours.weekdays
    end

    if operating_schedule do
      current_time = datetime.time
      start_time = Time.from_iso8601!(operating_schedule.start)
      end_time = Time.from_iso8601!(operating_schedule.end)

      Time.compare(current_time, start_time) in [:eq, :gt] &&
      Time.compare(current_time, end_time) in [:eq, :lt]
    else
      true # Always operating if no schedule specified
    end
  end

  @doc """
  Check if it's peak hour
  """
  @spec is_peak_hour?(t(), DateTime.t()) :: boolean()
  def is_peak_hour?(lane, datetime \\ DateTime.utc_now()) do
    current_time = datetime.time

    Enum.any?(lane.peak_hours, fn peak_hour ->
      start_time = Time.from_iso8601!(peak_hour.start)
      end_time = Time.from_iso8601!(peak_hour.end)

      Time.compare(current_time, start_time) in [:eq, :gt] &&
      Time.compare(current_time, end_time) in [:eq, :lt]
    end)
  end

  @doc """
  Get demand level (0-100%)
  """
  @spec get_demand_level(t()) :: float()
  def get_demand_level(lane) do
    if lane.capacity_per_hour > 0 do
      min(100.0, lane.current_demand / lane.capacity_per_hour * 100.0)
    else
      0.0
    end
  end

  defp calculate_wait_time(demand, capacity) do
    if capacity > 0 do
      base_wait = 5 # minutes
      additional_wait = demand / capacity * 10
      round(base_wait + additional_wait)
    else
      5
    end
  end

  defp calculate_distance({lat1, lng1}, {lat2, lng2}) do
    :math.sqrt(:math.pow(lat2 - lat1, 2) + :math.pow(lng2 - lng1, 2))
  end

  defp generate_color_code do
    colors = [
      "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
      "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
    ]
    Enum.random(colors)
  end
end
