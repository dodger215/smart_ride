# db/payment.ex
defmodule SmartBus.DB.Payment do
  @moduledoc """
  Payment entity for handling transactions
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          trip_id: binary(),
          passenger_id: binary(),
          driver_id: binary(),
          amount: float(),
          commission: float(),
          driver_amount: float(),
          platform_fee: float(),
          payment_method: :cash | :mobile_money | :card,
          payment_gateway: String.t() | nil,
          gateway_transaction_id: String.t() | nil,
          gateway_response: map() | nil,
          status: :pending | :processing | :completed | :failed | :refunded,
          refund_amount: float() | nil,
          refund_reason: String.t() | nil,
          metadata: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :trip_id,
    :passenger_id,
    :driver_id,
    :amount,
    :commission,
    :driver_amount,
    :platform_fee,
    :payment_method,
    :payment_gateway,
    :gateway_transaction_id,
    :gateway_response,
    :status,
    :refund_amount,
    :refund_reason,
    :metadata,
    :created_at,
    :updated_at
  ]

  @doc """
  Create a new payment
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    amount = attrs[:amount] || 0.0
    commission_rate = attrs[:commission_rate] || 0.15
    platform_fee = attrs[:platform_fee] || 5.0

    commission = amount * commission_rate
    driver_amount = amount - commission - platform_fee

    payment = %__MODULE__{
      id: id,
      trip_id: attrs[:trip_id],
      passenger_id: attrs[:passenger_id],
      driver_id: attrs[:driver_id],
      amount: amount,
      commission: Float.round(commission, 2),
      driver_amount: Float.round(driver_amount, 2),
      platform_fee: platform_fee,
      payment_method: attrs[:payment_method] || :cash,
      payment_gateway: attrs[:payment_gateway],
      gateway_transaction_id: attrs[:gateway_transaction_id],
      gateway_response: attrs[:gateway_response] || %{},
      status: :pending,
      metadata: attrs[:metadata] || %{},
      created_at: now,
      updated_at: now
    }

    case DB.insert(:payment, Map.from_struct(payment)) do
      {:ok, _} -> {:ok, payment}
      error -> error
    end
  end

  @doc """
  Get payment by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:payment, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get payment by trip ID
  """
  @spec get_by_trip(binary()) :: t() | nil
  def get_by_trip(trip_id) do
    DB.query(:payment, trip_id: trip_id)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> List.first()
  end

  @doc """
  Get payments by passenger ID
  """
  @spec get_by_passenger(binary(), keyword()) :: list(t())
  def get_by_passenger(passenger_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    DB.query(:payment, passenger_id: passenger_id)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Get payments by driver ID
  """
  @spec get_by_driver(binary(), keyword()) :: list(t())
  def get_by_driver(driver_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    DB.query(:payment, driver_id: driver_id)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Update payment status
  """
  @spec update_status(binary(), atom(), map() | nil) :: {:ok, t()} | {:error, String.t()}
  def update_status(id, status, gateway_response \\ nil) when status in [
    :processing, :completed, :failed, :refunded
  ] do
    case get(id) do
      nil -> {:error, "Payment not found"}
      payment ->
        updated_payment = %{
          payment
          | status: status,
            gateway_response: gateway_response || payment.gateway_response,
            updated_at: DateTime.utc_now()
        }

        DB.update(:payment, id, Map.from_struct(updated_payment))
        {:ok, updated_payment}
    end
  end

  @doc """
  Process refund
  """
  @spec refund(binary(), float(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def refund(id, amount, reason) do
    case get(id) do
      nil -> {:error, "Payment not found"}
      payment ->
        refund_amount = min(amount, payment.amount)
        updated_payment = %{
          payment
          | status: :refunded,
            refund_amount: refund_amount,
            refund_reason: reason,
            updated_at: DateTime.utc_now()
        }

        DB.update(:payment, id, Map.from_struct(updated_payment))
        {:ok, updated_payment}
    end
  end

  @doc """
  Get daily earnings for driver
  """
  @spec get_daily_earnings(binary(), Date.t()) :: float()
  def get_daily_earnings(driver_id, date \\ Date.utc_today()) do
    DB.query(:payment, driver_id: driver_id, status: :completed)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.filter(&(Date.compare(Date.utc_date(&1.created_at), date) == :eq))
    |> Enum.map(& &1.driver_amount)
    |> Enum.sum()
    |> Float.round(2)
  end

  @doc """
  Get total earnings for driver
  """
  @spec get_total_earnings(binary()) :: float()
  def get_total_earnings(driver_id) do
    DB.query(:payment, driver_id: driver_id, status: :completed)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.map(& &1.driver_amount)
    |> Enum.sum()
    |> Float.round(2)
  end

  @doc """
  Get platform revenue for period
  """
  @spec get_platform_revenue(Date.t(), Date.t()) :: map()
  def get_platform_revenue(start_date, end_date) do
    DB.query(:payment, status: :completed)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.filter(&(Date.compare(Date.utc_date(&1.created_at), start_date) in [:eq, :gt] &&
                    Date.compare(Date.utc_date(&1.created_at), end_date) in [:eq, :lt]))
    |> Enum.reduce(%{commission: 0.0, platform_fee: 0.0, total: 0.0}, fn payment, acc ->
      %{
        commission: acc.commission + payment.commission,
        platform_fee: acc.platform_fee + payment.platform_fee,
        total: acc.total + payment.commission + payment.platform_fee
      }
    end)
  end
end
