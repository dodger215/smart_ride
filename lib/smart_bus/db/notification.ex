defmodule SmartBus.DB.Notification do
  @moduledoc """
  Notification entity for system notifications
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          user_id: binary(),
          title: String.t(),
          body: String.t(),
          type: :ride_update | :payment | :system | :promotion,
          data: map(),
          read: boolean(),
          created_at: DateTime.t()
        }

  defstruct [
    :id,
    :user_id,
    :title,
    :body,
    :type,
    :data,
    :read,
    :created_at
  ]

  def create(attrs) do
    id = UUID.uuid4()

    notification = %__MODULE__{
      id: id,
      user_id: attrs[:user_id],
      title: attrs[:title],
      body: attrs[:body],
      type: attrs[:type] || :system,
      data: attrs[:data] || %{},
      read: false,
      created_at: DateTime.utc_now()
    }

    DB.insert(:notification, Map.from_struct(notification))
  end

  def mark_as_read(id) do
    DB.update(:notification, id, %{read: true})
  end

  def get_unread(user_id) do
    DB.query(:notification, user_id: user_id, read: false)
    |> Enum.map(&struct(__MODULE__, &1.data))
  end
end
