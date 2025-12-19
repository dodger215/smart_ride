defmodule SmartBus.DB.Vehicle do
  @moduledoc """
  Vehicle entity representing buses
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          driver_id: binary(),
          name: String.t(),
          brand: String.t(),
          model: String.t(),
          year: integer(),
          color: String.t(),
          number_plate: String.t(),
          vehicle_license: String.t(),
          license_expiry: Date.t(),
          total_seats: integer(),
          seat_layout: map(),
          amenities: list(String.t()),
          photos: list(String.t()),
          status: :pending | :approved | :rejected | :suspended,
          inspection_date: Date.t() | nil,
          next_inspection: Date.t() | nil,
          insurance_number: String.t() | nil,
          insurance_expiry: Date.t() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :driver_id,
    :name,
    :brand,
    :model,
    :year,
    :color,
    :number_plate,
    :vehicle_license,
    :license_expiry,
    :total_seats,
    :seat_layout,
    :amenities,
    :photos,
    :status,
    :inspection_date,
    :next_inspection,
    :insurance_number,
    :insurance_expiry,
    :created_at,
    :updated_at
  ]

  @doc """
  Register a new vehicle
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    vehicle = %__MODULE__{
      id: id,
      driver_id: attrs[:driver_id],
      name: attrs[:name],
      brand: attrs[:brand],
      model: attrs[:model],
      year: attrs[:year],
      color: attrs[:color],
      number_plate: attrs[:number_plate],
      vehicle_license: attrs[:vehicle_license],
      license_expiry: attrs[:license_expiry],
      total_seats: attrs[:total_seats],
      seat_layout: attrs[:seat_layout] || default_seat_layout(attrs[:total_seats]),
      amenities: attrs[:amenities] || [],
      photos: attrs[:photos] || [],
      status: :pending,
      inspection_date: nil,
      next_inspection: nil,
      insurance_number: attrs[:insurance_number],
      insurance_expiry: attrs[:insurance_expiry],
      created_at: now,
      updated_at: now
    }

    case DB.insert(:vehicle, Map.from_struct(vehicle)) do
      {:ok, _} -> {:ok, vehicle}
      error -> error
    end
  end

  @doc """
  Get vehicle by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:vehicle, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get vehicles by driver ID
  """
  @spec get_by_driver(binary()) :: list(t())
  def get_by_driver(driver_id) do
    DB.query(:vehicle, driver_id: driver_id)
    |> Enum.map(&struct(__MODULE__, &1.data))
  end

  @doc """
  Update vehicle status
  """
  @spec update_status(binary(), atom()) :: {:ok, t()} | {:error, String.t()}
  def update_status(id, status) when status in [:approved, :rejected, :suspended] do
    case get(id) do
      nil -> {:error, "Vehicle not found"}
      vehicle ->
        updated_vehicle = %{
          vehicle
          | status: status,
            inspection_date: if(status == :approved, do: Date.utc_today(), else: vehicle.inspection_date),
            next_inspection: if(status == :approved, do: Date.add(Date.utc_today(), 365), else: vehicle.next_inspection),
            updated_at: DateTime.utc_now()
        }

        DB.update(:vehicle, id, Map.from_struct(updated_vehicle))
        {:ok, updated_vehicle}
    end
  end

  @doc """
  Update vehicle details
  """
  @spec update(binary(), map()) :: {:ok, t()} | {:error, String.t()}
  def update(id, attrs) do
    case get(id) do
      nil -> {:error, "Vehicle not found"}
      vehicle ->
        updated_vehicle = %{
          vehicle
          | name: attrs[:name] || vehicle.name,
            color: attrs[:color] || vehicle.color,
            amenities: attrs[:amenities] || vehicle.amenities,
            photos: attrs[:photos] || vehicle.photos,
            seat_layout: attrs[:seat_layout] || vehicle.seat_layout,
            insurance_number: attrs[:insurance_number] || vehicle.insurance_number,
            insurance_expiry: attrs[:insurance_expiry] || vehicle.insurance_expiry,
            updated_at: DateTime.utc_now()
        }

        DB.update(:vehicle, id, Map.from_struct(updated_vehicle))
        {:ok, updated_vehicle}
    end
  end

  @doc """
  Add photo to vehicle
  """
  @spec add_photo(binary(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def add_photo(id, photo_url) do
    case get(id) do
      nil -> {:error, "Vehicle not found"}
      vehicle ->
        updated_photos = [photo_url | vehicle.photos]
        updated_vehicle = %{vehicle | photos: updated_photos, updated_at: DateTime.utc_now()}

        DB.update(:vehicle, id, Map.from_struct(updated_vehicle))
        {:ok, updated_vehicle}
    end
  end

  @doc """
  Get approved vehicles
  """
  @spec get_approved() :: list(t())
  def get_approved() do
    DB.query(:vehicle, status: :approved)
    |> Enum.map(&struct(__MODULE__, &1.data))
  end

  @doc """
  Get vehicle with seat availability
  """
  @spec get_with_availability(binary()) :: map() | nil
  def get_with_availability(vehicle_id) do
    case get(vehicle_id) do
      nil -> nil
      vehicle ->
        seats = SmartBus.DB.Seat.get_by_vehicle(vehicle_id)
        available_seats = Enum.count(seats, &(&1.status == :available))

        %{
          vehicle: vehicle,
          seat_info: %{
            total_seats: vehicle.total_seats,
            available_seats: available_seats,
            occupancy_rate: (vehicle.total_seats - available_seats) / vehicle.total_seats * 100,
            seat_map: SmartBus.DB.Seat.get_seat_map(vehicle_id)
          }
        }
    end
  end

  defp default_seat_layout(total_seats) do
    rows = ceil(total_seats / 4)

    for row <- 1..rows do
      for col <- 1..4 do
        seat_number = (row - 1) * 4 + col
        if seat_number <= total_seats do
          %{
            seat_id: "seat_#{seat_number}",
            seat_number: seat_number,
            row: row,
            column: col,
            type: :standard,
            status: :available
          }
        end
      end
      |> Enum.filter(& &1)
    end
    |> List.flatten()
  end
end
