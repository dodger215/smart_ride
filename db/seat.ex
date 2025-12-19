defmodule SmartBus.DB.Seat do
  @moduledoc """
  Seat entity for managing bus seat availability and reservations
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          vehicle_id: binary(),
          trip_id: binary() | nil,
          seat_number: String.t(),
          seat_label: String.t(),
          row: integer(),
          column: integer(),
          seat_type: :standard | :premium | :priority | :accessible | :family,
          features: list(atom()), # :reclining, :usb, :tablet, :extra_legroom, :window, :aisle
          status: :available | :reserved | :occupied | :blocked | :maintenance,
          passenger_id: binary() | nil,
          reservation_id: binary() | nil,
          reserved_at: DateTime.t() | nil,
          occupied_at: DateTime.t() | nil,
          price_modifier: float(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :vehicle_id,
    :trip_id,
    :seat_number,
    :seat_label,
    :row,
    :column,
    :seat_type,
    :features,
    :status,
    :passenger_id,
    :reservation_id,
    :reserved_at,
    :occupied_at,
    :price_modifier,
    :created_at,
    :updated_at
  ]

  @doc """
  Create seats for a vehicle
  """
  @spec create_for_vehicle(binary(), map()) :: {:ok, list(t())} | {:error, String.t()}
  def create_for_vehicle(vehicle_id, layout_config) do
    seats = generate_seats(vehicle_id, layout_config)

    results = Enum.map(seats, fn seat ->
      DB.insert(:seat, Map.from_struct(seat))
    end)

    if Enum.any?(results, &match?({:error, _}, &1)) do
      {:error, "Failed to create some seats"}
    else
      {:ok, seats}
    end
  end

  @doc """
  Get seat by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:seat, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Get seats by vehicle ID
  """
  @spec get_by_vehicle(binary(), keyword()) :: list(t())
  def get_by_vehicle(vehicle_id, opts \\ []) do
    trip_id = Keyword.get(opts, :trip_id)
    status = Keyword.get(opts, :status)

    query = [vehicle_id: vehicle_id]
    query = if trip_id, do: Keyword.put(query, :trip_id, trip_id), else: query
    query = if status, do: Keyword.put(query, :status, status), else: query

    DB.query(:seat, query)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(&{&1.row, &1.column})
  end

  @doc """
  Get available seats for vehicle
  """
  @spec get_available(binary(), binary() | nil) :: list(t())
  def get_available(vehicle_id, trip_id \\ nil) do
    query = [vehicle_id: vehicle_id, status: :available]
    query = if trip_id, do: Keyword.put(query, :trip_id, trip_id), else: query

    DB.query(:seat, query)
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> Enum.sort_by(&{&1.row, &1.column})
  end

  @doc """
  Reserve a seat
  """
  @spec reserve(binary(), binary(), binary(), binary()) :: {:ok, t()} | {:error, String.t()}
  def reserve(seat_id, passenger_id, trip_id, reservation_id) do
    case get(seat_id) do
      nil -> {:error, "Seat not found"}
      seat when seat.status != :available ->
        {:error, "Seat not available"}
      seat ->
        now = DateTime.utc_now()
        updated_seat = %{
          seat
          | status: :reserved,
            passenger_id: passenger_id,
            trip_id: trip_id,
            reservation_id: reservation_id,
            reserved_at: now,
            updated_at: now
        }

        DB.update(:seat, seat_id, Map.from_struct(updated_seat))
        {:ok, updated_seat}
    end
  end

  @doc """
  Occupy a seat (passenger boarded)
  """
  @spec occupy(binary()) :: {:ok, t()} | {:error, String.t()}
  def occupy(seat_id) do
    case get(seat_id) do
      nil -> {:error, "Seat not found"}
      seat when seat.status not in [:reserved, :available] ->
        {:error, "Cannot occupy this seat"}
      seat ->
        now = DateTime.utc_now()
        updated_seat = %{
          seat
          | status: :occupied,
            occupied_at: now,
            updated_at: now
        }

        DB.update(:seat, seat_id, Map.from_struct(updated_seat))
        {:ok, updated_seat}
    end
  end

  @doc """
  Release a seat
  """
  @spec release(binary()) :: {:ok, t()} | {:error, String.t()}
  def release(seat_id) do
    case get(seat_id) do
      nil -> {:error, "Seat not found"}
      seat ->
        updated_seat = %{
          seat
          | status: :available,
            passenger_id: nil,
            reservation_id: nil,
            reserved_at: nil,
            occupied_at: nil,
            trip_id: nil,
            updated_at: DateTime.utc_now()
        }

        DB.update(:seat, seat_id, Map.from_struct(updated_seat))
        {:ok, updated_seat}
    end
  end

  @doc """
  Block a seat (for maintenance or other reasons)
  """
  @spec block(binary(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def block(seat_id, reason \\ "Maintenance") do
    case get(seat_id) do
      nil -> {:error, "Seat not found"}
      seat when seat.status == :occupied ->
        {:error, "Cannot block occupied seat"}
      seat ->
        updated_seat = %{
          seat
          | status: :blocked,
            updated_at: DateTime.utc_now()
        }

        DB.update(:seat, seat_id, Map.from_struct(updated_seat))
        {:ok, updated_seat}
    end
  end

  @doc """
  Unblock a seat
  """
  @spec unblock(binary()) :: {:ok, t()} | {:error, String.t()}
  def unblock(seat_id) do
    case get(seat_id) do
      nil -> {:error, "Seat not found"}
      seat when seat.status != :blocked ->
        {:error, "Seat is not blocked"}
      seat ->
        updated_seat = %{
          seat
          | status: :available,
            updated_at: DateTime.utc_now()
        }

        DB.update(:seat, seat_id, Map.from_struct(updated_seat))
        {:ok, updated_seat}
    end
  end

  @doc """
  Get seat availability count
  """
  @spec get_availability_count(binary(), binary() | nil) :: integer()
  def get_availability_count(vehicle_id, trip_id \\ nil) do
    get_available(vehicle_id, trip_id)
    |> length()
  end

  @doc """
  Get seat map for vehicle
  """
  @spec get_seat_map(binary(), binary() | nil) :: map()
  def get_seat_map(vehicle_id, trip_id \\ nil) do
    seats = get_by_vehicle(vehicle_id, trip_id: trip_id)

    %{
      total_seats: length(seats),
      available_seats: Enum.count(seats, &(&1.status == :available)),
      reserved_seats: Enum.count(seats, &(&1.status == :reserved)),
      occupied_seats: Enum.count(seats, &(&1.status == :occupied)),
      blocked_seats: Enum.count(seats, &(&1.status == :blocked)),
      seats_by_row: group_seats_by_row(seats),
      premium_seats: Enum.filter(seats, &(&1.seat_type == :premium)),
      accessible_seats: Enum.filter(seats, &(&1.seat_type == :accessible))
    }
  end

  @doc """
  Find seats with specific features
  """
  @spec find_seats_with_features(binary(), list(atom()), binary() | nil) :: list(t())
  def find_seats_with_features(vehicle_id, features, trip_id \\ nil) do
    get_available(vehicle_id, trip_id)
    |> Enum.filter(fn seat ->
      Enum.all?(features, &(&1 in seat.features))
    end)
  end

  @doc """
  Reserve multiple seats
  """
  @spec reserve_multiple(list(binary()), binary(), binary(), binary()) ::
        {:ok, list(t())} | {:error, String.t(), list(t())}
  def reserve_multiple(seat_ids, passenger_id, trip_id, reservation_id) do
    # Check all seats are available first
    unavailable_seats = Enum.filter(seat_ids, fn seat_id ->
      case get(seat_id) do
        nil -> true
        seat -> seat.status != :available
      end
    end)

    if Enum.any?(unavailable_seats) do
      {:error, "Some seats are not available", unavailable_seats}
    else
      # Reserve all seats
      results = Enum.map(seat_ids, fn seat_id ->
        reserve(seat_id, passenger_id, trip_id, reservation_id)
      end)

      reserved_seats = Enum.filter(results, &match?({:ok, _}, &1))

      if length(reserved_seats) == length(seat_ids) do
        {:ok, Enum.map(reserved_seats, fn {:ok, seat} -> seat end)}
      else
        # Rollback any reservations that succeeded
        Enum.each(seat_ids, &release/1)
        {:error, "Failed to reserve all seats", []}
      end
    end
  end

  defp generate_seats(vehicle_id, layout_config) do
    total_seats = layout_config.total_seats
    rows = layout_config.rows || div(total_seats, 4)
    columns = layout_config.columns || 4

    seat_types = layout_config.seat_types || %{
      standard: 0.0,
      premium: 10.0,
      priority: 5.0,
      accessible: 0.0,
      family: 0.0
    }

    seat_features = layout_config.seat_features || %{
      window: [:window],
      aisle: [:aisle],
      premium: [:reclining, :usb, :extra_legroom],
      accessible: [:extra_space, :near_door]
    }

    for row <- 1..rows, col <- 1..columns, seat_num = (row - 1) * columns + col, seat_num <= total_seats do
      seat_type = determine_seat_type(seat_num, seat_types, total_seats)
      features = determine_seat_features(row, col, columns, seat_features)

      %__MODULE__{
        id: UUID.uuid4(),
        vehicle_id: vehicle_id,
        seat_number: "S#{String.pad_leading(seat_num |> Integer.to_string(), 3, "0")}",
        seat_label: "#{row}#{(col + 64) |> List.to_string()}",
        row: row,
        column: col,
        seat_type: seat_type,
        features: features,
        status: :available,
        price_modifier: Map.get(seat_types, seat_type, 0.0),
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end
  end

  defp determine_seat_type(seat_num, seat_types, total_seats) do
    # First row is premium
    if seat_num <= 4 do
      :premium
    # Last 2 seats are accessible
    else if seat_num > total_seats - 2 do
      :accessible
    # Every 5th seat is priority
    else if rem(seat_num, 5) == 0 do
      :priority
    # Seats 7-10 are family seats
    else if seat_num in 7..10 do
      :family
    else
      :standard
    end
    end
    end
    end
  end

  defp determine_seat_features(row, col, total_columns, seat_features) do
    features = []

    # Window seats
    features = if col == 1, do: [:window | features], else: features

    # Aisle seats
    features = if col == total_columns, do: [:aisle | features], else: features

    # Premium row features
    features = if row == 1, do: [:reclining, :usb, :extra_legroom | features], else: features

    # Accessible seats features (last row)
    features = if row >= 3, do: [:extra_space | features], else: features

    features
  end

  defp group_seats_by_row(seats) do
    seats
    |> Enum.group_by(& &1.row)
    |> Enum.map(fn {row, row_seats} ->
      %{
        row: row,
        seats: Enum.sort_by(row_seats, & &1.column),
        available: Enum.count(row_seats, &(&1.status == :available))
      }
    end)
    |> Enum.sort_by(& &1.row)
  end
end
