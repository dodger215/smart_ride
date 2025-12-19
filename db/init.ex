# db/init.ex
defmodule SmartBus.DB.Init do
  @moduledoc """
  Database initialization and seed data
  """

  alias SmartBus.DB

  def seed do
    # Create sample routes
    routes = [
      %{
        name: "City Center Express",
        code: "CCE-1",
        lane: "city_center_express",
        start_point: {1.2921, 36.8219}, # Nairobi coordinates
        end_point: {1.3000, 36.8300},
        distance_km: 5.2,
        estimated_time_minutes: 15,
        base_fare: 50.0,
        per_km_fare: 10.0,
        per_minute_fare: 2.0
      },
      %{
        name: "Westlands Shuttle",
        code: "WS-2",
        lane: "westlands_shuttle",
        start_point: {1.2700, 36.8000},
        end_point: {1.2800, 36.8100},
        distance_km: 3.8,
        estimated_time_minutes: 12,
        base_fare: 40.0,
        per_km_fare: 8.0,
        per_minute_fare: 1.5
      }
    ]

    Enum.each(routes, &SmartBus.DB.Route.create/1)

    # Create admin user
    admin_user = %{
      phone: "+254700000000",
      email: "admin@smartbus.com",
      password: "admin123",
      role: :admin,
      full_name: "System Administrator"
    }

    SmartBus.DB.User.create(admin_user)

    IO.puts("Database seeded successfully!")
  end

  def reset do
    # Clear all data
    types = [
      :user, :driver, :vehicle, :route, :trip, :payment,
      :ride_request, :gps_log, :review, :notification
    ]

    Enum.each(types, fn type ->
      DB.query(type)
      |> Enum.each(fn record ->
        DB.delete(type, record.id)
      end)
    end)

    IO.puts("Database reset successfully!")
  end
end
