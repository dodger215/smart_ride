
defmodule SmartBus.DB.RideRequest do
  @moduledoc """
  Ride request entity for passenger ride requests
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          passenger_id: binary(),
          lane: String.t(),
          pickup_location: {float(), float()},
          dropoff_location: {float(), float()},
          seats_requested: integer(),
          estimated_fare: float(),
          estimated_distance: float(),
          estimated_time: integer(),
          status: :pending | :matched | :accepted | :rejected | :timeout | :cancelled,
          matched_driver_id: binary() | nil,
          matched_vehicle_id: binary() | nil,
          expires_at: DateTime.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :passenger_id,
    :lane,
    :pickup_location,
    :dropoff_location,
    :seats_requested,
    :estimated_fare,
    :estimated_distance,
    :estimated_time,
    :status,
    :matched_driver_id,
    :matched_vehicle_id,
    :expires_at,
    :created_at,
    :updated_at
  ]

  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    request = %__MODULE__{
      id: id,
      passenger_id: attrs[:passenger_id],
      lane: attrs[:lane],
      pickup_location: attrs[:pickup_location],
      dropoff_location: attrs[:dropoff_location],
      seats_requested: attrs[:seats_requested] || 1,
      estimated_fare: attrs[:estimated_fare] || 0.0,
      estimated_distance: attrs[:estimated_distance] || 0.0,
      estimated_time: attrs[:estimated_time] || 0,
      status: :pending,
      expires_at: DateTime.add(now, 300), # 5 minutes
      created_at: now,
      updated_at: now
    }

    case DB.insert(:ride_request, Map.from_struct(request)) do
      {:ok, _} -> {:ok, request}
      error -> error
    end
  end

  def get(id), do: DB.get(:user, id) |> map_to_struct()
  def update_status(id, status), do: DB.update(:ride_request, id, %{status: status})
  def match(id, driver_id, vehicle_id), do: DB.update(:ride_request, id, %{
    status: :matched, matched_driver_id: driver_id, matched_vehicle_id: vehicle_id
  })

  defp map_to_struct(nil), do: nil
  defp map_to_struct(record), do: struct(__MODULE__, record.data)
end
