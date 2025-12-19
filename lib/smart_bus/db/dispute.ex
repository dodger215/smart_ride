defmodule SmartBus.DB.Dispute do
  @moduledoc """
  Dispute entity for handling customer complaints and issues
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          ticket_number: String.t(),
          user_id: binary(),
          driver_id: binary() | nil,
          trip_id: binary() | nil,
          payment_id: binary() | nil,
          type: :ride_issue | :payment_issue | :driver_complaint | :passenger_complaint | :lost_item | :other,
          category: :cancellation | :overcharging | :rude_behavior | :safety_concern | :cleanliness | :late_arrival | :damage | :other,
          title: String.t(),
          description: String.t(),
          status: :open | :in_review | :resolved | :closed | :escalated,
          priority: :low | :medium | :high | :critical,
          assigned_admin_id: binary() | nil,
          resolution: String.t() | nil,
          resolved_by: binary() | nil,
          resolved_at: DateTime.t() | nil,
          attachments: list(String.t()),
          user_rating: integer() | nil,
          admin_notes: String.t() | nil,
          refund_amount: float() | nil,
          penalty_amount: float() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :ticket_number,
    :user_id,
    :driver_id,
    :trip_id,
    :payment_id,
    :type,
    :category,
    :title,
    :description,
    :status,
    :priority,
    :assigned_admin_id,
    :resolution,
    :resolved_by,
    :resolved_at,
    :attachments,
    :user_rating,
    :admin_notes,
    :refund_amount,
    :penalty_amount,
    :created_at,
    :updated_at
  ]

  @doc """
  Create a new dispute
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    ticket_number = generate_ticket_number()

    dispute = %__MODULE__{
      id: id,
      ticket_number: ticket_number,
      user_id: attrs[:user_id],
      driver_id: attrs[:driver_id],
      trip_id: attrs[:trip_id],
      payment_id: attrs[:payment_id],
      type: attrs[:type] || :other,
      category: attrs[:category] || :other,
      title: attrs[:title],
      description: attrs[:description],
      status: :open,
      priority: calculate_priority(attrs[:type], attrs[:category]),
      attachments: attrs[:attachments] || [],
      created_at: now,
      updated_at: now
    }

    case DB.insert(:dispute, Map.from_struct(dispute)) do
      {:ok, _} -> {:ok, dispute}
      error -> error
    end
  end

  @doc """
  Get dispute by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:dispute, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get dispute by ticket number
  """
  @spec get_by_ticket(String.t()) :: t() | nil
  def get_by_ticket(ticket_number) do
    DB.query(:dispute, ticket_number: ticket_number)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> List.first()
  end

  @doc """
  Get disputes by user ID
  """
  @spec get_by_user(binary(), keyword()) :: list(t())
  def get_by_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status)

    query = [user_id: user_id]
    query = if status, do: Keyword.put(query, :status, status), else: query

    DB.query(:dispute, query)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Get disputes by driver ID
  """
  @spec get_by_driver(binary(), keyword()) :: list(t())
  def get_by_driver(driver_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    status = Keyword.get(opts, :status)

    query = [driver_id: driver_id]
    query = if status, do: Keyword.put(query, :status, status), else: query

    DB.query(:dispute, query)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Get open disputes for admin
  """
  @spec get_open_disputes(keyword()) :: list(t())
  def get_open_disputes(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    priority = Keyword.get(opts, :priority)

    query = [status: :open]
    query = if priority, do: Keyword.put(query, :priority, priority), else: query

    DB.query(:dispute, query)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(&{priority_value(&1.priority), &1.created_at}, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Update dispute status
  """
  @spec update_status(binary(), atom()) :: {:ok, t()} | {:error, String.t()}
  def update_status(id, status) when status in [:in_review, :resolved, :closed, :escalated] do
    case get(id) do
      nil -> {:error, "Dispute not found"}
      dispute ->
        updates = %{
          status: status,
          updated_at: DateTime.utc_now()
        }

        updates = if status == :resolved do
          Map.merge(updates, %{
            resolved_at: DateTime.utc_now(),
            resolved_by: dispute.assigned_admin_id
          })
        else
          updates
        end

        updated_dispute = struct(dispute, updates)

        DB.update(:dispute, id, Map.from_struct(updated_dispute))
        {:ok, updated_dispute}
    end
  end

  @doc """
  Assign dispute to admin
  """
  @spec assign_admin(binary(), binary()) :: {:ok, t()} | {:error, String.t()}
  def assign_admin(id, admin_id) do
    case get(id) do
      nil -> {:error, "Dispute not found"}
      dispute ->
        updated_dispute = %{
          dispute
          | assigned_admin_id: admin_id,
            status: :in_review,
            updated_at: DateTime.utc_now()
        }

        DB.update(:dispute, id, Map.from_struct(updated_dispute))
        {:ok, updated_dispute}
    end
  end

  @doc """
  Add resolution to dispute
  """
  @spec resolve(binary(), String.t(), map()) :: {:ok, t()} | {:error, String.t()}
  def resolve(id, resolution, details) do
    case get(id) do
      nil -> {:error, "Dispute not found"}
      dispute ->
        updates = %{
          resolution: resolution,
          admin_notes: details[:notes],
          refund_amount: details[:refund_amount],
          penalty_amount: details[:penalty_amount],
          status: :resolved,
          resolved_at: DateTime.utc_now(),
          resolved_by: dispute.assigned_admin_id,
          updated_at: DateTime.utc_now()
        }

        updated_dispute = struct(dispute, updates)

        DB.update(:dispute, id, Map.from_struct(updated_dispute))
        {:ok, updated_dispute}
    end
  end

  @doc """
  Add attachment to dispute
  """
  @spec add_attachment(binary(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def add_attachment(id, attachment_url) do
    case get(id) do
      nil -> {:error, "Dispute not found"}
      dispute ->
        updated_attachments = [attachment_url | dispute.attachments]
        updated_dispute = %{dispute | attachments: updated_attachments, updated_at: DateTime.utc_now()}

        DB.update(:dispute, id, Map.from_struct(updated_dispute))
        {:ok, updated_dispute}
    end
  end

  @doc """
  Get dispute statistics
  """
  @spec get_statistics(Date.t(), Date.t()) :: map()
  def get_statistics(start_date, end_date) do
    DB.query(:dispute)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.filter(&dispute_in_period?(&1, start_date, end_date))
    |> Enum.reduce(%{
      total: 0,
      open: 0,
      resolved: 0,
      by_type: %{},
      by_category: %{},
      avg_resolution_hours: 0.0,
      resolution_rate: 0.0
    }, fn dispute, acc ->
      # Count totals
      acc = %{
        acc
        | total: acc.total + 1,
          open: acc.open + if(dispute.status == :open, do: 1, else: 0),
          resolved: acc.resolved + if(dispute.status == :resolved, do: 1, else: 0)
      }

      # Count by type
      acc = update_in(acc[:by_type][dispute.type], fn count -> (count || 0) + 1 end)

      # Count by category
      acc = update_in(acc[:by_category][dispute.category], fn count -> (count || 0) + 1 end)

      acc
    end)
    |> then(fn stats ->
      # Calculate averages
      resolution_rate = if stats.total > 0, do: stats.resolved / stats.total * 100, else: 0
      %{stats | resolution_rate: Float.round(resolution_rate, 2)}
    end)
  end

  defp generate_ticket_number do
    date = Date.utc_today() |> Date.to_iso8601() |> String.replace("-", "")
    random = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
    "DISP-#{date}-#{random}"
  end

  defp calculate_priority(type, category) do
    case {type, category} do
      {:safety_concern, _} -> :critical
      {:payment_issue, :overcharging} -> :high
      {_, :damage} -> :high
      _ -> :medium
    end
  end

  defp priority_value(:critical), do: 4
  defp priority_value(:high), do: 3
  defp priority_value(:medium), do: 2
  defp priority_value(:low), do: 1

  defp dispute_in_period?(dispute, start_date, end_date) do
    dispute_date = Date.utc_date(dispute.created_at)
    Date.compare(dispute_date, start_date) in [:eq, :gt] &&
    Date.compare(dispute_date, end_date) in [:eq, :lt]
  end
end
