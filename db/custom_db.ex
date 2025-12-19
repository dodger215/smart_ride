defmodule SmartBus.DB do
  @db_file "smart_bus.db"

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def insert(type, data) do
    id = UUID.uuid4()
    now = DateTime.utc_now()
    record = %SmartBus.DB.Schema{
      id: id,
      type: type,
      data: data,
      created_at: now,
      updated_at: now
    }

    Agent.update(__MODULE__, fn state ->
      Map.put(state, {type, id}, record)
    end)

    {:ok, record}
  end

  def get(type, id) do
    Agent.get(__MODULE__, fn state ->
      Map.get(state, {type, id})
    end)
  end

  def update(type, id, updates) do
    Agent.update(__MODULE__, fn state ->
      case Map.get(state, {type, id}) do
        nil -> state
        record ->
          updated_data = Map.merge(record.data, updates)
          updated_record = %{record |
            data: updated_data,
            updated_at: DateTime.utc_now()
          }
          Map.put(state, {type, id}, updated_record)
      end
    end)
  end

  def delete(type, id) do
    Agent.update(__MODULE__, fn state ->
      case Map.get(state, {type, id}) do
        nil -> state
        record ->
          Map.put(state, {type, id}, %{record | deleted_at: DateTime.utc_now()})
      end
    end)
  end

  def query(type, filters \\ []) do
    Agent.get(__MODULE__, fn state ->
      state
      |> Map.values()
      |> Enum.filter(fn record ->
        record.type == type && is_nil(record.deleted_at)
      end)
      |> Enum.filter(fn record ->
        Enum.all?(filters, fn {key, value} ->
          Map.get(record.data, key) == value
        end)
      end)
    end)
  end

  def save_to_file do
    data = Agent.get(__MODULE__, & &1)
    File.write!(@db_file, :erlang.term_to_binary(data))
  end

  def load_from_file do
    if File.exists?(@db_file) do
      data = File.read!(@db_file) |> :erlang.binary_to_term()
      Agent.update(__MODULE__, fn _ -> data end)
    end
  end
end
