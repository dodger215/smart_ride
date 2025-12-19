defmodule SmartBus.DB.User do
  @moduledoc """
  User entity for passengers, drivers, and admins
  """

  alias SmartBus.DB

  @type t :: %__MODULE__{
          id: binary(),
          phone: String.t(),
          email: String.t(),
          password_hash: String.t(),
          role: :passenger | :driver | :admin,
          full_name: String.t() | nil,
          profile_picture: String.t() | nil,
          status: :pending | :verified | :suspended | :banned,
          otp: String.t() | nil,
          otp_expires_at: DateTime.t() | nil,
          preferences: map(),
          emergency_contact: map() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          deleted_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :phone,
    :email,
    :password_hash,
    :role,
    :full_name,
    :profile_picture,
    :status,
    :otp,
    :otp_expires_at,
    :preferences,
    :emergency_contact,
    :created_at,
    :updated_at,
    :deleted_at
  ]

  @doc """
  Create a new user
  """
  @spec create(map()) :: {:ok, t()} | {:error, String.t()}
  def create(attrs) do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    user = %__MODULE__{
      id: id,
      phone: attrs[:phone],
      email: attrs[:email],
      password_hash: hash_password(attrs[:password]),
      role: attrs[:role] || :passenger,
      full_name: attrs[:full_name],
      profile_picture: attrs[:profile_picture],
      status: :pending,
      otp: generate_otp(),
      otp_expires_at: DateTime.add(now, 300), # 5 minutes
      preferences: attrs[:preferences] || %{},
      emergency_contact: attrs[:emergency_contact],
      created_at: now,
      updated_at: now
    }

    case DB.insert(:user, Map.from_struct(user)) do
      {:ok, _} -> {:ok, user}
      error -> error
    end
  end

  @doc """
  Get user by ID
  """
  @spec get(binary()) :: t() | nil
  def get(id) do
    case DB.get(:user, id) do
      nil -> nil
      record -> struct(__MODULE__, record.data)
    end
  end

  @doc """
  Find user by phone
  """
  @spec find_by_phone(String.t()) :: t() | nil
  def find_by_phone(phone) do
    DB.query(:user, phone: phone)
    |> Enum.filter(&(&1.deleted_at == nil))
    |> Enum.map(&struct(__MODULE__, &1.data))
    |> List.first()
  end

  @doc """
  Update user
  """
  @spec update(binary(), map()) :: {:ok, t()} | {:error, String.t()}
  def update(id, attrs) do
    case get(id) do
      nil -> {:error, "User not found"}
      user ->
        updated_user = %{
          user
          | full_name: attrs[:full_name] || user.full_name,
            profile_picture: attrs[:profile_picture] || user.profile_picture,
            preferences: Map.merge(user.preferences, attrs[:preferences] || %{}),
            emergency_contact: attrs[:emergency_contact] || user.emergency_contact,
            updated_at: DateTime.utc_now()
        }

        DB.update(:user, id, Map.from_struct(updated_user))
        {:ok, updated_user}
    end
  end

  @doc """
  Verify user OTP
  """
  @spec verify_otp(binary(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def verify_otp(id, otp) do
    case get(id) do
      nil -> {:error, "User not found"}
      user ->
        cond do
          user.otp != otp -> {:error, "Invalid OTP"}
          DateTime.compare(user.otp_expires_at, DateTime.utc_now()) == :lt ->
            {:error, "OTP expired"}
          true ->
            updated_user = %{
              user
              | status: :verified,
                otp: nil,
                otp_expires_at: nil,
                updated_at: DateTime.utc_now()
            }

            DB.update(:user, id, Map.from_struct(updated_user))
            {:ok, updated_user}
        end
    end
  end

  @doc """
  Authenticate user
  """
  @spec authenticate(String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def authenticate(phone, password) do
    case find_by_phone(phone) do
      nil -> {:error, "Invalid credentials"}
      user ->
        if verify_password(password, user.password_hash) do
          {:ok, user}
        else
          {:error, "Invalid credentials"}
        end
    end
  end

  @doc """
  Change user status
  """
  @spec change_status(binary(), atom()) :: {:ok, t()} | {:error, String.t()}
  def change_status(id, status) when status in [:verified, :suspended, :banned] do
    case get(id) do
      nil -> {:error, "User not found"}
      user ->
        updated_user = %{user | status: status, updated_at: DateTime.utc_now()}
        DB.update(:user, id, Map.from_struct(updated_user))
        {:ok, updated_user}
    end
  end

  defp hash_password(password) do
    :crypto.hash(:sha256, password)
    |> Base.encode64()
  end

  defp verify_password(password, hash) do
    hash_password(password) == hash
  end

  defp generate_otp do
    :rand.uniform(899_999) + 100_000
    |> Integer.to_string()
  end
end
