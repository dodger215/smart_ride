defmodule SmartBus.DB.Schema do
  @type t :: %__MODULE__{
          id: binary(),
          type: atom(),
          data: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          deleted_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :type,
    :data,
    :created_at,
    :updated_at,
    :deleted_at
  ]
end
