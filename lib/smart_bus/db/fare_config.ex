defmodule SmartBus.DB.FareConfig do
  @moduledoc """
  Fare configuration for dynamic pricing and fare rules
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          name: String.t(),
          description: String.t(),
          lane: String.t() | nil, # nil means global configuration
          base_fare: float(),
          per_km_fare: float(),
          per_minute_fare: float(),
          min_fare: float(),
          max_fare: float(),
          surge_multiplier: float(),
          surge_start_time: Time.t() | nil,
          surge_end_time: Time.t() | nil,
          surge_days: list(atom()),
          surge_conditions: list(atom()), # :rain, :traffic, :demand, :event
          commission_rate: float(),
          platform_fee: float(),
          discount_percentage: float(),
          discount_code: String.t() | nil,
          discount_start: DateTime.t() | nil,
          discount_end: DateTime.t() | nil,
          is_active: boolean(),
          created_by: binary() | nil, # admin ID
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          valid_from: DateTime.t(),
          valid_to: DateTime.t() | nil
        }

  defstruct [
    :id,
    :name,
    :description,
    :lane,
    :base_fare,
    :per_km_fare,
    :per_minute_fare,
    :min_fare,
    :max_fare,
    :surge_multiplier,
    :surge_start_time,
    :surge_end_time,
    :surge_days,
    :surge_conditions,
    :commission_rate,
    :platform_fee,
    :discount_percentage,
    :discount_code,
    :discount_start,
    :discount_end,
    :is_active,
    :created_by,
    :created_at,
    :updated_at,
    :valid_from,
    :valid_to
  ]

  @doc """
  Create a new fare configuration
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    fare_config = %__MODULE__{
      id: id,
      name: attrs[:name],
      description: attrs[:description],
      lane: attrs[:lane],
      base_fare: attrs[:base_fare] || 50.0,
      per_km_fare: attrs[:per_km_fare] || 10.0,
      per_minute_fare: attrs[:per_minute_fare] || 2.0,
      min_fare: attrs[:min_fare] || 30.0,
      max_fare: attrs[:max_fare] || 500.0,
      surge_multiplier: attrs[:surge_multiplier] || 1.0,
      surge_start_time: attrs[:surge_start_time],
      surge_end_time: attrs[:surge_end_time],
      surge_days: attrs[:surge_days] || [:monday, :tuesday, :wednesday, :thursday, :friday],
      surge_conditions: attrs[:surge_conditions] || [],
      commission_rate: attrs[:commission_rate] || 0.15,
      platform_fee: attrs[:platform_fee] || 5.0,
      discount_percentage: attrs[:discount_percentage] || 0.0,
      discount_code: attrs[:discount_code],
      discount_start: attrs[:discount_start],
      discount_end: attrs[:discount_end],
      is_active: true,
      created_by: attrs[:created_by],
      created_at: now,
      updated_at: now,
      valid_from: attrs[:valid_from] || now,
      valid_to: attrs[:valid_to]
    }

    case DB.insert(:fare_config, Map.from_struct(fare_config)) do
      {:ok, _} -> {:ok, fare_config}
      error -> error
    end
  end

  @doc """
  Get fare configuration by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:fare_config, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get active fare configuration for a lane
  """
  @spec get_for_lane(String.t()) :: t() | nil
  def get_for_lane(lane) do
    now = DateTime.utc_now()

    DB.query(:fare_config, lane: lane, is_active: true)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.filter(&config_valid_now?(&1, now))
    |> Enum.sort_by(& &1.valid_from, :desc)
    |> List.first()
  end

  @doc """
  Get global fare configuration
  """
  @spec get_global() :: t() | nil
  def get_global() do
    now = DateTime.utc_now()

    DB.query(:fare_config, lane: nil, is_active: true)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.filter(&config_valid_now?(&1, now))
    |> Enum.sort_by(& &1.valid_from, :desc)
    |> List.first()
  end

  @doc """
  Calculate fare with dynamic pricing
  """
  @spec calculate_fare(t(), float(), integer(), DateTime.t(), map()) :: float()
  def calculate_fare(config, distance_km, time_minutes, timestamp, conditions \\ %{}) do
    # Base fare calculation
    base_fare = config.base_fare +
                (distance_km * config.per_km_fare) +
                (time_minutes * config.per_minute_fare)

    # Apply surge pricing
    surge_multiplier = get_surge_multiplier(config, timestamp, conditions)

    # Apply discounts
    discount_multiplier = 1.0 - (config.discount_percentage / 100.0)

    fare = base_fare * surge_multiplier * discount_multiplier

    # Apply min/max bounds
    fare
    |> max(config.min_fare)
    |> min(config.max_fare)
    |> Float.round(2)
  end

  @doc """
  Get commission amount
  """
  @spec get_commission(t(), float()) :: float()
  def get_commission(config, fare_amount) do
    commission = fare_amount * config.commission_rate
    Float.round(commission + config.platform_fee, 2)
  end

  @doc """
  Get driver earnings
  """
  @spec get_driver_earnings(t(), float()) :: float()
  def get_driver_earnings(config, fare_amount) do
    commission = get_commission(config, fare_amount)
    Float.round(fare_amount - commission, 2)
  end

  @doc """
  Update fare configuration
  """
  @spec update(binary(), map()) :: {:ok, t()} | {:error, String.t()}
  def update(id, attrs) do
    case get(id) do
      nil -> {:error, "Fare configuration not found"}
      config ->
        updated_config = %{
          config
          | name: attrs[:name] || config.name,
            description: attrs[:description] || config.description,
            base_fare: attrs[:base_fare] || config.base_fare,
            per_km_fare: attrs[:per_km_fare] || config.per_km_fare,
            per_minute_fare: attrs[:per_minute_fare] || config.per_minute_fare,
            min_fare: attrs[:min_fare] || config.min_fare,
            max_fare: attrs[:max_fare] || config.max_fare,
            surge_multiplier: attrs[:surge_multiplier] || config.surge_multiplier,
            commission_rate: attrs[:commission_rate] || config.commission_rate,
            platform_fee: attrs[:platform_fee] || config.platform_fee,
            discount_percentage: attrs[:discount_percentage] || config.discount_percentage,
            is_active: if(Map.has_key?(attrs, :is_active), do: attrs[:is_active], else: config.is_active),
            updated_at: DateTime.utc_now()
        }

        DB.update(:fare_config, id, Map.from_struct(updated_config))
        {:ok, updated_config}
    end
  end

  @doc """
  Activate fare configuration
  """
  @spec activate(binary()) :: {:ok, t()} | {:error, String.t()}
  def activate(id) do
    case get(id) do
      nil -> {:error, "Fare configuration not found"}
      config ->
        updated_config = %{config | is_active: true, updated_at: DateTime.utc_now()}
        DB.update(:fare_config, id, Map.from_struct(updated_config))
        {:ok, updated_config}
    end
  end

  @doc """
  Deactivate fare configuration
  """
  @spec deactivate(binary()) :: {:ok, t()} | {:error, String.t()}
  def deactivate(id) do
    case get(id) do
      nil -> {:error, "Fare configuration not found"}
      config ->
        updated_config = %{config | is_active: false, updated_at: DateTime.utc_now()}
        DB.update(:fare_config, id, Map.from_struct(updated_config))
        {:ok, updated_config}
    end
  end

  defp get_surge_multiplier(config, timestamp, conditions) do
    # Check if surge pricing should apply
    if should_apply_surge?(config, timestamp, conditions) do
      config.surge_multiplier
    else
      1.0
    end
  end

  defp should_apply_surge?(config, timestamp, conditions) do
    # Check time-based surge
    time_surge = check_time_surge(config, timestamp)

    # Check condition-based surge
    condition_surge = check_condition_surge(config, conditions)

    time_surge || condition_surge
  end

  defp check_time_surge(config, timestamp) do
    if config.surge_start_time && config.surge_end_time do
      current_time = timestamp.time
      current_day = timestamp |> DateTime.to_date() |> Date.day_of_week() |> day_name()

      current_day in config.surge_days &&
      Time.compare(current_time, config.surge_start_time) in [:eq, :gt] &&
      Time.compare(current_time, config.surge_end_time) in [:eq, :lt]
    else
      false
    end
  end

  defp check_condition_surge(config, conditions) do
    Enum.any?(config.surge_conditions, fn condition ->
      Map.get(conditions, condition, false)
    end)
  end

  defp config_valid_now?(config, now) do
    # Check valid_from
    from_valid = DateTime.compare(now, config.valid_from) in [:eq, :gt]

    # Check valid_to if exists
    to_valid = if config.valid_to do
      DateTime.compare(now, config.valid_to) in [:eq, :lt]
    else
      true
    end

    from_valid && to_valid
  end

  defp day_name(1), do: :monday
  defp day_name(2), do: :tuesday
  defp day_name(3), do: :wednesday
  defp day_name(4), do: :thursday
  defp day_name(5), do: :friday
  defp day_name(6), do: :saturday
  defp day_name(7), do: :sunday
end
