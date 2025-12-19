# lib/smart_bus_web/channels/payment_channel.ex
defmodule SmartBusWeb.PaymentChannel do
  use Phoenix.Channel
  alias SmartBus.DB.Payment
  alias SmartBus.DB.Trip
  alias SmartBus.DB.Driver
  alias SmartBus.DB.FareConfig

  def join("payment:trip:" <> trip_id, _params, socket) do
    case Trip.get(trip_id) do
      nil -> {:error, %{reason: "Trip not found"}}
      _ ->
        socket = assign(socket, :trip_id, trip_id)
        {:ok, socket}
    end
  end

  def join("payment:driver:" <> driver_id, _params, socket) do
    socket = assign(socket, :driver_id, driver_id)
    {:ok, socket}
  end

  def join("payment:passenger:" <> passenger_id, _params, socket) do
    socket = assign(socket, :passenger_id, passenger_id)
    {:ok, socket}
  end

  def handle_in("calculate_fare", %{
    "distance" => distance,
    "time" => time,
    "lane" => lane,
    "seats" => seats
  }, socket) do
    # Get fare configuration for lane
    fare_config = FareConfig.get_for_lane(lane) || FareConfig.get_global()

    if fare_config do
      fare = FareConfig.calculate_fare(fare_config, distance, time, DateTime.utc_now(), %{})
      total_fare = fare * seats

      {:reply, {:ok, %{
        base_fare: fare,
        total_fare: total_fare,
        breakdown: %{
          distance_charge: distance * fare_config.per_km_fare,
          time_charge: time * fare_config.per_minute_fare,
          base_charge: fare_config.base_fare,
          seats_multiplier: seats,
          surge_multiplier: 1.0
        },
        currency: "KES"
      }}, socket}
    else
      {:reply, {:error, %{reason: "Fare configuration not found"}}, socket}
    end
  end

  def handle_in("process_payment", %{
    "payment_method" => method,
    "amount" => amount,
    "details" => details
  }, socket) do
    trip_id = socket.assigns.trip_id

    case Trip.get(trip_id) do
      nil ->
        {:reply, {:error, %{reason: "Trip not found"}}, socket}

      trip ->
        # Create payment record
        payment_data = %{
          trip_id: trip_id,
          passenger_id: trip.passenger_id,
          driver_id: trip.driver_id,
          amount: amount,
          payment_method: String.to_atom(method),
          payment_gateway: details["gateway"],
          gateway_transaction_id: details["transaction_id"]
        }

        case Payment.create(payment_data) do
          {:ok, payment} ->
            # Process payment based on method
            result = process_payment_gateway(payment, details)

            case result do
              {:success, transaction_id} ->
                # Update payment status
                Payment.update_status(payment.id, :completed, %{
                  transaction_id: transaction_id,
                  processed_at: DateTime.utc_now()
                })

                # Update trip payment status
                Trip.update_payment(trip_id, :paid, payment.id)

                # Update driver earnings
                Driver.add_earnings(trip.driver_id, payment.driver_amount)

                # Notify both parties
                broadcast_to_passenger(trip.passenger_id, "payment_success", %{
                  trip_id: trip_id,
                  amount: amount,
                  transaction_id: transaction_id
                })

                broadcast_to_driver(trip.driver_id, "payment_received", %{
                  trip_id: trip_id,
                  amount: payment.driver_amount,
                  transaction_id: transaction_id
                })

                {:reply, {:ok, %{
                  status: "success",
                  transaction_id: transaction_id,
                  message: "Payment processed successfully"
                }}, socket}

              {:failed, error} ->
                Payment.update_status(payment.id, :failed, %{error: error})
                {:reply, {:error, %{reason: error}}, socket}
            end

          {:error, reason} ->
            {:reply, {:error, %{reason: reason}}, socket}
        end
    end
  end

  def handle_in("refund_payment", %{"payment_id" => payment_id, "reason" => reason}, socket) do
    case Payment.get(payment_id) do
      nil ->
        {:reply, {:error, %{reason: "Payment not found"}}, socket}

      payment ->
        # Process refund
        refund_result = process_refund(payment, reason)

        case refund_result do
          {:success, refund_id} ->
            Payment.refund(payment.id, payment.amount, reason)

            # Update trip status if needed
            Trip.update_payment(payment.trip_id, :refunded)

            {:reply, {:ok, %{
              refund_id: refund_id,
              amount: payment.amount,
              message: "Refund processed successfully"
            }}, socket}

          {:failed, error} ->
            {:reply, {:error, %{reason: error}}, socket}
        end
    end
  end

  def handle_in("view_receipt", %{"payment_id" => payment_id}, socket) do
    case Payment.get(payment_id) do
      nil ->
        {:reply, {:error, %{reason: "Payment not found"}}, socket}

      payment ->
        # Get trip details
        trip = Trip.get(payment.trip_id)

        receipt = %{
          receipt_id: "RCPT-#{payment.id}",
          trip_date: trip.created_at,
          passenger_name: get_passenger_name(trip.passenger_id),
          driver_name: get_driver_name(trip.driver_id),
          vehicle_number: get_vehicle_number(trip.driver_id),
          pickup_location: trip.pickup_location,
          dropoff_location: trip.dropoff_location,
          fare_breakdown: %{
            base_fare: 0.0, # Calculate from fare config
            distance_charge: 0.0,
            time_charge: 0.0,
            surge_multiplier: 1.0,
            total: payment.amount
          },
          payment_details: %{
            method: payment.payment_method,
            transaction_id: payment.gateway_transaction_id,
            date: payment.created_at
          }
        }

        {:reply, {:ok, %{receipt: receipt}}, socket}
    end
  end

  def handle_in("view_earnings", %{"period" => period}, socket) do
    driver_id = socket.assigns.driver_id

    earnings = case period do
      "today" -> Payment.get_daily_earnings(driver_id)
      "total" -> Payment.get_total_earnings(driver_id)
      _ -> 0.0
    end

    # Get payment history
    payments = Payment.get_by_driver(driver_id, limit: 50)

    {:reply, {:ok, %{
      earnings: earnings,
      payments: payments,
      period: period
    }}, socket}
  end

  def handle_in("process_cash_payment", %{"amount" => amount, "received" => received}, socket) do
    trip_id = socket.assigns.trip_id

    if received >= amount do
      change = received - amount

      # Create cash payment record
      payment_data = %{
        trip_id: trip_id,
        amount: amount,
        payment_method: :cash,
        status: :completed
      }

      {:ok, _payment} = Payment.create(payment_data)

      {:reply, {:ok, %{
        status: "success",
        amount_paid: amount,
        change: change,
        message: "Cash payment received"
      }}, socket}
    else
      {:reply, {:error, %{
        reason: "Insufficient amount",
        required: amount,
        received: received
      }}, socket}
    end
  end

  defp process_payment_gateway(payment, details) do
    # Integrate with payment gateway (Paystack, Flutterwave, Stripe)
    # This is a mock implementation

    case payment.payment_method do
      :mobile_money ->
        # Process mobile money payment
        {:success, "MM-#{UUID.uuid4()}"}
      :card ->
        # Process card payment
        {:success, "CARD-#{UUID.uuid4()}"}
      :cash ->
        {:success, "CASH-#{UUID.uuid4()}"}
      _ ->
        {:failed, "Unsupported payment method"}
    end
  end

  defp process_refund(payment, reason) do
    # Process refund through payment gateway
    {:success, "REF-#{UUID.uuid4()}"}
  end

  defp get_passenger_name(passenger_id) do
    "Passenger"
  end

  defp get_driver_name(driver_id) do
    case Driver.get(driver_id) do
      nil -> "Driver"
      _ -> "Driver Name"
    end
  end

  defp get_vehicle_number(driver_id) do
    "KAA 123A"
  end

  defp broadcast_to_passenger(passenger_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("passenger:#{passenger_id}", event, payload)
  end

  defp broadcast_to_driver(driver_id, event, payload) do
    SmartBusWeb.Endpoint.broadcast("driver:#{driver_id}", event, payload)
  end
end
