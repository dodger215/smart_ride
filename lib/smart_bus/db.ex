defmodule SmartBus.DB do
  @moduledoc """
  Custom in-memory database for the Smart Bus application.
  """

  use GenServer

  @db_file "smart_bus.db"

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def insert(type, data) do
    GenServer.call(__MODULE__, {:insert, type, data})
  end

  def get(type, id) do
    GenServer.call(__MODULE__, {:get, type, id})
  end

  def update(type, id, updates) do
    GenServer.call(__MODULE__, {:update, type, id, updates})
  end

  def delete(type, id) do
    GenServer.call(__MODULE__, {:delete, type, id})
  end

  def query(type, filters \\ []) do
    GenServer.call(__MODULE__, {:query, type, filters})
  end

  def save_to_file do
    GenServer.call(__MODULE__, :save_to_file)
  end

  def load_from_file do
    GenServer.call(__MODULE__, :load_from_file)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # Load data from file if it exists
    if File.exists?(@db_file) do
      data = File.read!(@db_file) |> :erlang.binary_to_term()
      {:ok, data}
    else
      {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:insert, type, data}, _from, state) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    record = %{
      id: id,
      type: type,
      data: data,
      created_at: now,
      updated_at: now,
      deleted_at: nil
    }

    new_state = Map.put(state, {type, id}, record)
    {:reply, {:ok, record}, new_state}
  end

  @impl true
  def handle_call({:get, type, id}, _from, state) do
    record = Map.get(state, {type, id})
    {:reply, record, state}
  end

  @impl true
  def handle_call({:update, type, id, updates}, _from, state) do
    case Map.get(state, {type, id}) do
      nil ->
        {:reply, {:error, :not_found}, state}

      record ->
        updated_data = Map.merge(record.data, updates)
        updated_record = %{
          record
          | data: updated_data,
            updated_at: DateTime.utc_now()
        }

        new_state = Map.put(state, {type, id}, updated_record)
        {:reply, {:ok, updated_record}, new_state}
    end
  end

  @impl true
  def handle_call({:delete, type, id}, _from, state) do
    case Map.get(state, {type, id}) do
      nil ->
        {:reply, {:error, :not_found}, state}

      record ->
        updated_record = %{record | deleted_at: DateTime.utc_now()}
        new_state = Map.put(state, {type, id}, updated_record)
        {:reply, {:ok, updated_record}, new_state}
    end
  end

  @impl true
  def handle_call({:query, type, filters}, _from, state) do
    records = state
    |> Map.values()
    |> Enum.filter(fn record ->
      record.type == type && is_nil(record.deleted_at)
    end)
    |> Enum.filter(fn record ->
      Enum.all?(filters, fn {key, value} ->
        Map.get(record.data, key) == value
      end)
    end)

    {:reply, records, state}
  end

  @impl true
  def handle_call(:save_to_file, _from, state) do
    binary = :erlang.term_to_binary(state)
    File.write!(@db_file, binary)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:load_from_file, _from, _state) do
    if File.exists?(@db_file) do
      data = File.read!(@db_file) |> :erlang.binary_to_term()
      {:reply, {:ok, data}, data}
    else
      {:reply, {:error, :file_not_found}, %{}}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Save to file on termination
    binary = :erlang.term_to_binary(state)
    File.write!(@db_file, binary)
    :ok
  end
end
