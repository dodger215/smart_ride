defmodule SmartBus.DB.Driver do
  @moduledoc """
  Driver entity representing bus owners/operators
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          user_id: binary(),
          driver_license: String.t(),
          license_expiry: Date.t(),
          identity_document: String.t(),
          document_verified: boolean(),
          status: :pending | :verified | :suspended,
          current_location: {float(), float()} | nil,
          current_lane: binary() | nil,
          current_route: map() | nil,
          available_seats: integer(),
          total_seats: integer(),
          is_online: boolean(),
          last_online: DateTime.t() | nil,
          rating: float(),
          total_rides: integer(),
          earnings_today: float(),
          earnings_total: float(),
          commission_rate: float(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :user_id,
    :driver_license,
    :license_expiry,
    :identity_document,
    :document_verified,
    :status,
    :current_location,
    :current_lane,
    :current_route,
    :available_seats,
    :total_seats,
    :is_online,
    :last_online,
    :rating,
    :total_rides,
    :earnings_today,
    :earnings_total,
    :commission_rate,
    :created_at,
    :updated_at
  ]

  @doc """
  Create a new driver
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    driver = %__MODULE__{
      id: id,
      user_id: attrs[:user_id],
      driver_license: attrs[:driver_license],
      license_expiry: attrs[:license_expiry],
      identity_document: attrs[:identity_document],
      document_verified: false,
      status: :pending,
      current_location: nil,
      current_lane: nil,
      current_route: nil,
      available_seats: 0,
      total_seats: attrs[:total_seats] || 0,
      is_online: false,
      last_online: nil,
      rating: 0.0,
      total_rides: 0,
      earnings_today: 0.0,
      earnings_total: 0.0,
      commission_rate: 0.15, # Default 15%
      created_at: now,
      updated_at: now
    }

    case DB.insert(:driver, Map.from_struct(driver)) do
      {:ok, _} -> {:ok, driver}
      error -> error
    end
  end

  @doc """
  Get driver by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:driver, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get driver by user ID
  """
  @spec get_by_user(binary()) :: t() | nil
  def get_by_user(user_id) do
    DB.query(:driver, user_id: user_id)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> List.first()
  end

  @doc """
  Update driver availability
  """
  @spec go_online(binary(), map()) :: {:ok, t()} | {:error, String.t()}
  def go_online(driver_id, %{location: location, lane: lane, available_seats: seats}) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        updated_driver = %{
          driver
          | is_online: true,
            current_location: location,
            current_lane: lane,
            available_seats: seats,
            last_online: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Take driver offline
  """
  @spec go_offline(binary()) :: {:ok, t()} | {:error, String.t()}
  def go_offline(driver_id) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        updated_driver = %{
          driver
          | is_online: false,
            last_online: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Update driver location
  """
  @spec update_location(binary(), {float(), float()}) :: {:ok, t()} | {:error, String.t()}
  def update_location(driver_id, location) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        updated_driver = %{
          driver
          | current_location: location,
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Update driver route
  """
  @spec update_route(binary(), map()) :: {:ok, t()} | {:error, String.t()}
  def update_route(driver_id, route) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        updated_driver = %{
          driver
          | current_route: route,
            current_lane: route[:lane],
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Reserve seats on driver's bus
  """
  @spec reserve_seats(binary(), integer()) :: {:ok, t()} | {:error, String.t()}
  def reserve_seats(driver_id, seats) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver when driver.available_seats < seats ->
        {:error, "Not enough seats available"}
      driver ->
        updated_driver = %{
          driver
          | available_seats: driver.available_seats - seats,
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Release seats on driver's bus
  """
  @spec release_seats(binary(), integer()) :: {:ok, t()} | {:error, String.t()}
  def release_seats(driver_id, seats) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        new_seats = min(driver.available_seats + seats, driver.total_seats)
        updated_driver = %{
          driver
          | available_seats: new_seats,
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Add earnings to driver
  """
  @spec add_earnings(binary(), float()) :: {:ok, t()} | {:error, String.t()}
  def add_earnings(driver_id, amount) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        updated_driver = %{
          driver
          | earnings_today: driver.earnings_today + amount,
            earnings_total: driver.earnings_total + amount,
            total_rides: driver.total_rides + 1,
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Reset daily earnings
  """
  @spec reset_daily_earnings(binary()) :: {:ok, t()} | {:error, String.t()}
  def reset_daily_earnings(driver_id) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        updated_driver = %{
          driver
          | earnings_today: 0.0,
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Update driver rating
  """
  @spec update_rating(binary(), float()) :: {:ok, t()} | {:error, String.t()}
  def update_rating(driver_id, new_rating) do
    case get(driver_id) do
      nil -> {:error, "Driver not found"}
      driver ->
        # Calculate new average rating
        total_score = driver.rating * driver.total_rides + new_rating
        new_average = total_score / (driver.total_rides + 1)

        updated_driver = %{
          driver
          | rating: Float.round(new_average, 2),
            updated_at: DateTime.utc_now()
        }

        DB.update(:driver, driver_id, Map.from_struct(updated_driver))
        {:ok, updated_driver}
    end
  end

  @doc """
  Find online drivers on a specific lane
  """
  @spec find_online_on_lane(binary(), integer()) :: list(t())
  def find_online_on_lane(lane, min_seats \\ 1) do
    DB.query(:driver, is_online: true, current_lane: lane)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.filter(&(&1.available_seats >= min_seats))
  end
end
