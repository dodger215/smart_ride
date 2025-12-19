# db/gps_log.ex
defmodule SmartBus.DB.GPSLog do
  @moduledoc """
  GPS tracking logs for vehicles
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          vehicle_id: binary(),
          driver_id: binary(),
          latitude: float(),
          longitude: float(),
          speed: float(),
          heading: float(),
          accuracy: float(),
          battery_level: integer(),
          trip_id: binary() | nil,
          timestamp: DateTime.t()
        }

  defstruct [
    :id,
    :vehicle_id,
    :driver_id,
    :latitude,
    :longitude,
    :speed,
    :heading,
    :accuracy,
    :battery_level,
    :trip_id,
    :timestamp
  ]

  def create(attrs) do
    id = UUID.uuid4()

    log = %__MODULE__{
      id: id,
      vehicle_id: attrs[:vehicle_id],
      driver_id: attrs[:driver_id],
      latitude: attrs[:latitude],
      longitude: attrs[:longitude],
      speed: attrs[:speed] || 0.0,
      heading: attrs[:heading] || 0.0,
      accuracy: attrs[:accuracy] || 10.0,
      battery_level: attrs[:battery_level] || 100,
      trip_id: attrs[:trip_id],
      timestamp: DateTime.utc_now()
    }

    DB.insert(:gps_log, Map.from_struct(log))
  end

  def get_recent(vehicle_id, limit \\ 100) do
    DB.query(:gps_log, vehicle_id: vehicle_id)
    |> Enum.sort_by(& &1.data.timestamp, :desc)
    |> Enum.take(limit)
    |> Enum.map(&struct(__MODULE__, &1.data))
  end
end
