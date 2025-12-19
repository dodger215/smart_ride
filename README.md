# SmartRide

A real-time bus transportation management system built with Phoenix and Elixir, featuring WebSocket-based communication for live tracking, booking, and driver management.

## Getting Started

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## WebSocket Channels Documentation

SmartBus uses 19 WebSocket channels for real-time communication. Connect to the WebSocket endpoint at `ws://localhost:4000/socket` and join channels with the topic format specified below.

### Channel: auth
**Topic:** `auth:user` | `auth:driver` | `auth:admin`

User authentication and account management events.

**Events:**
- `register` - Register a new user account
- `login` - User login authentication
- `logout` - User logout
- `verify_otp` - Verify one-time password
- `reset_password` - Reset user password

---

### Channel: passenger
**Topic:** `passenger:user:USER_ID`

Passenger profile and ride history management.

**Events:**
- `create_profile` - Create passenger profile
- `update_profile` - Update passenger information
- `view_profile` - Retrieve passenger profile
- `view_ride_history` - View past rides
- `delete_account` - Delete passenger account

---

### Channel: driver
**Topic:** `driver:DRIVER_ID`

Driver account and profile management.

**Events:**
- `register_driver` - Register as a driver
- `update_profile` - Update driver information
- `upload_documents` - Upload driver documents
- `verify_account` - Verify driver account
- `suspend_account` - Suspend driver account

---

### Channel: vehicle
**Topic:** `vehicle:VEHICLE_ID`

Vehicle registration and management.

**Events:**
- `register_vehicle` - Register a new vehicle
- `update_details` - Update vehicle information
- `upload_photos` - Upload vehicle photos
- `approve_vehicle` - Admin approval of vehicle
- `reject_vehicle` - Reject vehicle registration
- `deactivate_vehicle` - Deactivate vehicle

---

### Channel: availability
**Topic:** `availability:driver:DRIVER_ID`

Driver availability and route management.

**Events:**
- `go_online` - Driver goes online
- `go_offline` - Driver goes offline
- `set_route` - Set driver's route
- `update_route` - Update current route
- `set_stops` - Set route stops

---

### Channel: ride_request
**Topic:** `ride_request:passenger:USER_ID`

Passenger ride request management.

**Events:**
- `create_request` - Create a new ride request
- `cancel_request` - Cancel pending ride request
- `view_available_buses` - List available buses
- `match_passenger` - Match passenger with driver
- `request_timeout` - Handle request timeout

---

### Channel: ride_management
**Topic:** `ride_management:trip:TRIP_ID`

Trip and ride lifecycle management.

**Events:**
- `accept_request` - Driver accepts ride request
- `reject_request` - Driver rejects ride request
- `start_trip` - Driver starts the trip
- `end_trip` - Driver completes the trip
- `cancel_trip` - Cancel active trip
- `board_passenger` - Passenger boards the bus
- `alight_passenger` - Passenger alights from bus

---

### Channel: seat_management
**Topic:** `seat_management:vehicle:VEHICLE_ID`

Vehicle seat availability and reservation.

**Events:**
- `check_availability` - Check available seats
- `reserve_seat` - Reserve a specific seat
- `release_seat` - Release reserved seat
- `update_capacity` - Update vehicle capacity

---

### Channel: tracking
**Topic:** `tracking:trip:TRIP_ID`

Real-time bus tracking and location updates.

**Events:**
- `update_location` - Update bus GPS location
- `get_eta` - Get estimated time of arrival
- `track_bus` - Get current bus location
- `geofence_alert` - Alert for geofence events

---

### Channel: payment
**Topic:** `payment:system`

Payment processing and financial transactions.

**Events:**
- `calculate_fare` - Calculate trip fare
- `process_payment` - Process payment transaction
- `refund_payment` - Process refund
- `view_receipt` - Get payment receipt
- `view_earnings` - View driver earnings

---

### Channel: notification
**Topic:** `notification:user:USER_ID`

User notifications and alerts.

**Events:**
- `arrival_alert` - Bus arrival notification
- `booking_confirmation` - Booking confirmed
- `driver_assigned` - Driver assigned to trip
- `payment_success` - Payment successful
- `ride_cancelled` - Ride cancelled notification
- `availability_update` - Availability status update

---

### Channel: admin
**Topic:** `admin:system` | `admin:dashboard`

Administrative operations and monitoring.

**Events:**
- `approve_driver` - Approve driver registration
- `verify_vehicle` - Verify vehicle registration
- `suspend_user` - Suspend user account
- `monitor_trips` - Monitor active trips
- `view_reports` - View system reports
- `configure_fares` - Configure fare rates
- `handle_dispute` - Handle disputes

---

### Channel: gps
**Topic:** `gps:vehicle:VEHICLE_ID`

GPS logging and navigation.

**Events:**
- `log_location` - Log GPS coordinates
- `get_navigation` - Get navigation data
- `optimize_route` - Optimize travel route
- `detect_stops` - Detect route stops

---

### Channel: review
**Topic:** `review:trip:TRIP_ID`

Trip reviews and ratings.

**Events:**
- `submit_review` - Submit trip review
- `rate_driver` - Rate driver performance
- `rate_passenger` - Rate passenger behavior
- `view_ratings` - View ratings and reviews

---

### Channel: reports
**Topic:** `reports:admin`

Analytics and reporting.

**Events:**
- `generate_daily_earnings` - Generate earnings report
- `view_transaction_history` - View transaction records
- `trip_statistics` - Get trip statistics
- `popular_routes` - Get popular routes data
- `active_drivers_count` - Get active drivers count

---

### Channel: integration
**Topic:** `integration:system`

External API integrations and webhooks.

**Events:**
- `maps_api_call` - Call maps API
- `payment_gateway` - Payment gateway integration
- `send_sms` - Send SMS notification
- `push_notification` - Send push notification
- `webhook_event` - Handle webhook events

---

### Channel: dynamic_pricing
**Topic:** `pricing:system`

Dynamic pricing and fare calculations.

**Events:**
- `calculate_dynamic_fare` - Calculate dynamic fare based on demand
- `update_surge_multiplier` - Update pricing multiplier
- `view_pricing_rules` - View current pricing rules

---

### Channel: offline_operations
**Topic:** `offline:device:DEVICE_ID`

Offline mode operations for mobile clients.

**Events:**
- `queue_request` - Queue request for offline sync
- `sync_data` - Sync offline data
- `offline_available_buses` - Get available buses (offline cache)

---

---

## Client Testing Examples

### JavaScript/Web Testing

#### Auth Channel Test
```javascript
const socket = new PhoenixSocket("ws://localhost:4000/socket");
const channel = socket.channel("auth:user");

channel.join()
  .receive("ok", () => {
    // Register event
    channel.push("register", {
      email: "user@example.com",
      password: "password123",
      name: "John Doe"
    })
    .receive("ok", (response) => console.log("Registered:", response))
    .receive("error", (error) => console.error("Registration failed:", error));
    
    // Login event
    channel.push("login", {
      email: "user@example.com",
      password: "password123"
    })
    .receive("ok", (response) => console.log("Logged in:", response));
  })
  .receive("error", (err) => console.error("Failed to join:", err));
```

#### Passenger Channel Test
```javascript
const passengerChannel = socket.channel("passenger:user:user_123");

passengerChannel.join()
  .receive("ok", () => {
    passengerChannel.push("create_profile", {
      name: "Jane Doe",
      phone: "1234567890",
      email: "jane@example.com"
    });
    
    passengerChannel.push("view_ride_history", {})
      .receive("ok", (rides) => console.log("Rides:", rides));
  });
```

#### Tracking Channel Test
```javascript
const trackingChannel = socket.channel("tracking:trip:trip_456");

trackingChannel.join()
  .receive("ok", () => {
    trackingChannel.on("update_location", (data) => {
      console.log("Bus location updated:", data.latitude, data.longitude);
    });
    
    trackingChannel.push("get_eta", {})
      .receive("ok", (eta) => console.log("ETA:", eta.minutes, "minutes"));
  });
```

---

### Kotlin/Android Testing

#### Auth Channel Test
```kotlin
import com.pusher.client.Pusher
import com.pusher.client.channel.PrivateChannel
import org.json.JSONObject

val pusher = Pusher("app-key", "app-secret", "app-cluster")
val channel = pusher.subscribe("auth:user") as PrivateChannel

channel.bind("register") { event ->
    try {
        val json = JSONObject(event.data)
        Log.d("Auth", "Registration response: ${json.getString("message")}")
    } catch (e: Exception) {
        Log.e("Auth", "Error: ${e.message}")
    }
}

// Trigger register event
val registerData = JSONObject().apply {
    put("email", "user@example.com")
    put("password", "password123")
    put("name", "John Doe")
}
channel.trigger("client-register", registerData)
```

#### Passenger Channel Test
```kotlin
import com.pusher.client.Pusher

val passengerChannel = pusher.subscribe("passenger:user:user_123") as PrivateChannel

passengerChannel.bind("profile_created") { event ->
    val data = JSONObject(event.data)
    Log.d("Passenger", "Profile created: ${data.getString("profile_id")}")
}

passengerChannel.bind("ride_history") { event ->
    val rides = JSONObject(event.data).getJSONArray("rides")
    Log.d("Passenger", "Total rides: ${rides.length()}")
}

// Request ride history
val historyRequest = JSONObject().apply {
    put("user_id", "user_123")
}
passengerChannel.trigger("client-view_ride_history", historyRequest)
```

#### Tracking Channel Test
```kotlin
val trackingChannel = pusher.subscribe("tracking:trip:trip_456") as PrivateChannel

trackingChannel.bind("location_update") { event ->
    val location = JSONObject(event.data)
    val lat = location.getDouble("latitude")
    val lng = location.getDouble("longitude")
    Log.d("Tracking", "Bus at: $lat, $lng")
    
    // Update map UI
    updateMapMarker(lat, lng)
}

trackingChannel.bind("eta_updated") { event ->
    val eta = JSONObject(event.data)
    Log.d("Tracking", "ETA: ${eta.getInt("minutes")} minutes")
}
```

---

### Flutter Testing

#### Auth Channel Test
```dart
import 'package:phoenix_socket/phoenix_socket.dart';

final socket = PhoenixSocket("ws://localhost:4000/socket");

void testAuthChannel() {
  final channel = socket.channel("auth:user");
  
  channel.join()
    .receive("ok", (_) {
      // Register
      channel.push("register", payload: {
        "email": "user@example.com",
        "password": "password123",
        "name": "John Doe"
      }).receive("ok", (response) {
        print("Registered: $response");
      }).receive("error", (error) {
        print("Registration failed: $error");
      });
      
      // Login
      channel.push("login", payload: {
        "email": "user@example.com",
        "password": "password123"
      }).receive("ok", (response) {
        print("Logged in: $response");
      });
    })
    .receive("error", (error) {
      print("Failed to join auth channel: $error");
    });
}
```

#### Passenger Channel Test
```dart
void testPassengerChannel() {
  final channel = socket.channel("passenger:user:user_123");
  
  channel.join()
    .receive("ok", (_) {
      // Create profile
      channel.push("create_profile", payload: {
        "name": "Jane Doe",
        "phone": "1234567890",
        "email": "jane@example.com"
      }).receive("ok", (response) {
        print("Profile created: $response");
      });
      
      // View ride history
      channel.push("view_ride_history", payload: {})
        .receive("ok", (rides) {
          print("Ride history: $rides");
        });
      
      // Listen for ride updates
      channel.on("ride_update", (payload) {
        print("Ride updated: $payload");
      });
    });
}
```

#### Tracking Channel Test
```dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

void testTrackingChannel() {
  final channel = socket.channel("tracking:trip:trip_456");
  
  channel.join()
    .receive("ok", (_) {
      // Listen for location updates
      channel.on("update_location", (payload) {
        final lat = payload['latitude'] as double;
        final lng = payload['longitude'] as double;
        print("Bus location: $lat, $lng");
        
        // Update map
        _updateMapMarker(LatLng(lat, lng));
      });
      
      // Listen for ETA updates
      channel.on("eta_updated", (payload) {
        final minutes = payload['minutes'] as int;
        print("ETA: $minutes minutes");
        setState(() {
          eta = minutes;
        });
      });
      
      // Request current location
      channel.push("track_bus", payload: {
        "trip_id": "trip_456"
      }).receive("ok", (location) {
        print("Current location: $location");
      });
    });
}

void _updateMapMarker(LatLng position) {
  setState(() {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: MarkerId("bus_location"),
        position: position,
        infoWindow: InfoWindow(title: "Bus Location"),
      ),
    );
  });
}
```

#### Notification Channel Test
```dart
void testNotificationChannel() {
  final channel = socket.channel("notification:user:user_123");
  
  channel.join()
    .receive("ok", (_) {
      // Listen for various notifications
      channel.on("arrival_alert", (payload) {
        _showNotification("Bus Arrival", payload['message']);
      });
      
      channel.on("booking_confirmation", (payload) {
        _showNotification("Booking Confirmed", 
          "Your booking reference: ${payload['reference_id']}");
      });
      
      channel.on("payment_success", (payload) {
        _showNotification("Payment Success", 
          "Amount: \$${payload['amount']}");
      });
      
      channel.on("ride_cancelled", (payload) {
        _showNotification("Ride Cancelled", payload['reason']);
      });
    });
}

void _showNotification(String title, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("$title: $message")),
  );
}
```

#### Payment Channel Test
```dart
void testPaymentChannel() {
  final channel = socket.channel("payment:system");
  
  channel.join()
    .receive("ok", (_) {
      // Calculate fare
      channel.push("calculate_fare", payload: {
        "pickup_lat": 40.7128,
        "pickup_lng": -74.0060,
        "dropoff_lat": 40.7580,
        "dropoff_lng": -73.9855,
        "surge_multiplier": 1.5
      }).receive("ok", (fare) {
        print("Calculated fare: \$${fare['amount']}");
      });
      
      // Process payment
      channel.push("process_payment", payload: {
        "amount": 25.50,
        "payment_method": "credit_card",
        "transaction_id": "txn_123456"
      }).receive("ok", (response) {
        print("Payment processed: ${response['receipt_id']}");
      });
      
      // View earnings
      channel.push("view_earnings", payload: {
        "driver_id": "driver_123",
        "start_date": "2024-12-01",
        "end_date": "2024-12-19"
      }).receive("ok", (earnings) {
        print("Total earnings: \$${earnings['total']}");
      });
    });
}
```

#### Driver Channel Test
```dart
void testDriverChannel() {
  final channel = socket.channel("driver:driver_123");
  
  channel.join()
    .receive("ok", (_) {
      // Register driver
      channel.push("register_driver", payload: {
        "name": "John Smith",
        "phone": "9876543210",
        "license_number": "DL123456",
        "email": "john@example.com"
      }).receive("ok", (response) {
        print("Driver registered: ${response['driver_id']}");
      });
      
      // Update profile
      channel.push("update_profile", payload: {
        "experience_years": 5,
        "rating": 4.8
      }).receive("ok", (response) {
        print("Profile updated");
      });
      
      // Upload documents
      channel.push("upload_documents", payload: {
        "license": "base64_encoded_license",
        "insurance": "base64_encoded_insurance"
      }).receive("ok", (response) {
        print("Documents uploaded");
      });
      
      // Listen for account status
      channel.on("account_status", (payload) {
        print("Account status: ${payload['status']}");
      });
    });
}
```

#### Vehicle Channel Test
```dart
void testVehicleChannel() {
  final channel = socket.channel("vehicle:vehicle_456");
  
  channel.join()
    .receive("ok", (_) {
      // Register vehicle
      channel.push("register_vehicle", payload: {
        "registration_number": "ABC1234",
        "make": "Volvo",
        "model": "B7R",
        "capacity": 45,
        "color": "White"
      }).receive("ok", (response) {
        print("Vehicle registered: ${response['vehicle_id']}");
      });
      
      // Update details
      channel.push("update_details", payload: {
        "last_service_date": "2024-11-15",
        "odometer_reading": 125000
      }).receive("ok", (_) {
        print("Vehicle details updated");
      });
      
      // Upload photos
      channel.push("upload_photos", payload: {
        "photos": ["base64_photo1", "base64_photo2"]
      }).receive("ok", (_) {
        print("Photos uploaded");
      });
      
      // Listen for approval status
      channel.on("vehicle_approved", (payload) {
        print("Vehicle approved by admin");
      });
    });
}
```

#### Availability Channel Test
```dart
void testAvailabilityChannel() {
  final channel = socket.channel("availability:driver:driver_123");
  
  channel.join()
    .receive("ok", (_) {
      // Go online
      channel.push("go_online", payload: {
        "latitude": 40.7128,
        "longitude": -74.0060
      }).receive("ok", (_) {
        print("Driver is now online");
      });
      
      // Set route
      channel.push("set_route", payload: {
        "route_id": "route_001",
        "start_point": "Central Station",
        "end_point": "Airport Terminal"
      }).receive("ok", (_) {
        print("Route set successfully");
      });
      
      // Set stops
      channel.push("set_stops", payload: {
        "stops": [
          {"name": "Stop 1", "lat": 40.7128, "lng": -74.0060},
          {"name": "Stop 2", "lat": 40.7200, "lng": -74.0100},
          {"name": "Stop 3", "lat": 40.7300, "lng": -74.0150}
        ]
      }).receive("ok", (_) {
        print("Stops configured");
      });
      
      // Go offline
      channel.push("go_offline", payload: {})
        .receive("ok", (_) {
          print("Driver is now offline");
        });
    });
}
```

#### Ride Request Channel Test
```dart
void testRideRequestChannel() {
  final channel = socket.channel("ride_request:passenger:user_123");
  
  channel.join()
    .receive("ok", (_) {
      // Create request
      channel.push("create_request", payload: {
        "pickup_location": "123 Main St",
        "dropoff_location": "456 Park Ave",
        "passengers": 2,
        "preferred_time": "2024-12-20 10:00"
      }).receive("ok", (response) {
        print("Ride request created: ${response['request_id']}");
      });
      
      // View available buses
      channel.push("view_available_buses", payload: {
        "pickup_lat": 40.7128,
        "pickup_lng": -74.0060,
        "radius": 5
      }).receive("ok", (buses) {
        print("Available buses: ${buses.length}");
      });
      
      // Listen for driver matches
      channel.on("driver_matched", (payload) {
        print("Driver assigned: ${payload['driver_name']}");
      });
      
      // Cancel request
      channel.push("cancel_request", payload: {
        "request_id": "req_123"
      }).receive("ok", (_) {
        print("Request cancelled");
      });
    });
}
```

#### Ride Management Channel Test
```dart
void testRideManagementChannel() {
  final channel = socket.channel("ride_management:trip:trip_456");
  
  channel.join()
    .receive("ok", (_) {
      // Accept request
      channel.push("accept_request", payload: {
        "request_id": "req_123"
      }).receive("ok", (_) {
        print("Ride request accepted");
      });
      
      // Start trip
      channel.push("start_trip", payload: {
        "trip_id": "trip_456"
      }).receive("ok", (_) {
        print("Trip started");
      });
      
      // Board passenger
      channel.push("board_passenger", payload: {
        "passenger_id": "user_123",
        "seat_number": 5
      }).receive("ok", (_) {
        print("Passenger boarded");
      });
      
      // Alight passenger
      channel.push("alight_passenger", payload: {
        "passenger_id": "user_123"
      }).receive("ok", (_) {
        print("Passenger alighted");
      });
      
      // End trip
      channel.push("end_trip", payload: {
        "trip_id": "trip_456",
        "total_passengers": 10
      }).receive("ok", (_) {
        print("Trip ended");
      });
      
      // Listen for status updates
      channel.on("trip_status", (payload) {
        print("Trip status: ${payload['status']}");
      });
    });
}
```

#### Seat Management Channel Test
```dart
void testSeatManagementChannel() {
  final channel = socket.channel("seat_management:vehicle:vehicle_456");
  
  channel.join()
    .receive("ok", (_) {
      // Check availability
      channel.push("check_availability", payload: {
        "trip_date": "2024-12-20"
      }).receive("ok", (availability) {
        print("Available seats: ${availability['available_count']}");
      });
      
      // Reserve seat
      channel.push("reserve_seat", payload: {
        "seat_number": 5,
        "passenger_id": "user_123"
      }).receive("ok", (_) {
        print("Seat reserved");
      });
      
      // Release seat
      channel.push("release_seat", payload: {
        "seat_number": 5
      }).receive("ok", (_) {
        print("Seat released");
      });
      
      // Update capacity
      channel.push("update_capacity", payload: {
        "total_capacity": 50,
        "wheelchair_spaces": 2
      }).receive("ok", (_) {
        print("Capacity updated");
      });
      
      // Listen for seat updates
      channel.on("seat_update", (payload) {
        print("Seat ${payload['seat_number']} status: ${payload['status']}");
      });
    });
}
```

#### Review Channel Test
```dart
void testReviewChannel() {
  final channel = socket.channel("review:trip:trip_456");
  
  channel.join()
    .receive("ok", (_) {
      // Submit review
      channel.push("submit_review", payload: {
        "trip_id": "trip_456",
        "comment": "Great service, very clean bus",
        "rating": 5
      }).receive("ok", (_) {
        print("Review submitted");
      });
      
      // Rate driver
      channel.push("rate_driver", payload: {
        "driver_id": "driver_123",
        "rating": 4.5,
        "comment": "Professional and courteous"
      }).receive("ok", (_) {
        print("Driver rated");
      });
      
      // Rate passenger
      channel.push("rate_passenger", payload: {
        "passenger_id": "user_123",
        "rating": 5,
        "comment": "Respectful passenger"
      }).receive("ok", (_) {
        print("Passenger rated");
      });
      
      // View ratings
      channel.push("view_ratings", payload: {
        "trip_id": "trip_456"
      }).receive("ok", (ratings) {
        print("Average rating: ${ratings['average_rating']}");
      });
    });
}
```

#### Reports Channel Test
```dart
void testReportsChannel() {
  final channel = socket.channel("reports:admin");
  
  channel.join()
    .receive("ok", (_) {
      // Generate daily earnings
      channel.push("generate_daily_earnings", payload: {
        "driver_id": "driver_123",
        "date": "2024-12-19"
      }).receive("ok", (report) {
        print("Daily earnings: \$${report['total_earnings']}");
      });
      
      // View transaction history
      channel.push("view_transaction_history", payload: {
        "user_id": "user_123",
        "limit": 50
      }).receive("ok", (transactions) {
        print("Transactions: ${transactions.length}");
      });
      
      // Trip statistics
      channel.push("trip_statistics", payload: {
        "start_date": "2024-12-01",
        "end_date": "2024-12-19"
      }).receive("ok", (stats) {
        print("Total trips: ${stats['total_trips']}");
        print("Total revenue: \$${stats['total_revenue']}");
      });
      
      // Popular routes
      channel.push("popular_routes", payload: {
        "limit": 10
      }).receive("ok", (routes) {
        print("Top route: ${routes[0]['name']}");
      });
      
      // Active drivers count
      channel.push("active_drivers_count", payload: {})
        .receive("ok", (data) {
          print("Active drivers: ${data['count']}");
        });
    });
}
```

#### GPS Channel Test
```dart
void testGpsChannel() {
  final channel = socket.channel("gps:vehicle:vehicle_456");
  
  channel.join()
    .receive("ok", (_) {
      // Log location
      channel.push("log_location", payload: {
        "latitude": 40.7128,
        "longitude": -74.0060,
        "accuracy": 5,
        "timestamp": DateTime.now().toIso8601String()
      }).receive("ok", (_) {
        print("Location logged");
      });
      
      // Get navigation
      channel.push("get_navigation", payload: {
        "destination_lat": 40.7580,
        "destination_lng": -73.9855
      }).receive("ok", (nav) {
        print("Distance: ${nav['distance']} km");
        print("ETA: ${nav['eta']} minutes");
      });
      
      // Optimize route
      channel.push("optimize_route", payload: {
        "waypoints": [
          {"lat": 40.7128, "lng": -74.0060},
          {"lat": 40.7200, "lng": -74.0100},
          {"lat": 40.7300, "lng": -74.0150}
        ]
      }).receive("ok", (optimized) {
        print("Optimized route distance: ${optimized['distance']} km");
      });
      
      // Detect stops
      channel.push("detect_stops", payload: {
        "route_id": "route_001"
      }).receive("ok", (stops) {
        print("Detected stops: ${stops.length}");
      });
    });
}
```

#### Admin Channel Test
```dart
void testAdminChannel() {
  final channel = socket.channel("admin:system");
  
  channel.join()
    .receive("ok", (_) {
      // Approve driver
      channel.push("approve_driver", payload: {
        "driver_id": "driver_123"
      }).receive("ok", (_) {
        print("Driver approved");
      });
      
      // Verify vehicle
      channel.push("verify_vehicle", payload: {
        "vehicle_id": "vehicle_456"
      }).receive("ok", (_) {
        print("Vehicle verified");
      });
      
      // Suspend user
      channel.push("suspend_user", payload: {
        "user_id": "user_123",
        "reason": "Suspicious activity"
      }).receive("ok", (_) {
        print("User suspended");
      });
      
      // Monitor trips
      channel.push("monitor_trips", payload: {
        "status_filter": "active"
      }).receive("ok", (trips) {
        print("Active trips: ${trips.length}");
      });
      
      // Configure fares
      channel.push("configure_fares", payload: {
        "base_fare": 2.50,
        "per_km": 1.50,
        "per_minute": 0.25
      }).receive("ok", (_) {
        print("Fare configuration updated");
      });
      
      // Listen for system events
      channel.on("system_alert", (payload) {
        print("Alert: ${payload['message']}");
      });
    });
}
```

#### Dynamic Pricing Channel Test
```dart
void testDynamicPricingChannel() {
  final channel = socket.channel("pricing:system");
  
  channel.join()
    .receive("ok", (_) {
      // Calculate dynamic fare
      channel.push("calculate_dynamic_fare", payload: {
        "base_fare": 10.0,
        "demand_level": "high",
        "time_of_day": "peak_hours"
      }).receive("ok", (fare) {
        print("Dynamic fare: \$${fare['calculated_fare']}");
        print("Surge multiplier: ${fare['surge_multiplier']}x");
      });
      
      // Update surge multiplier
      channel.push("update_surge_multiplier", payload: {
        "area": "downtown",
        "multiplier": 1.8
      }).receive("ok", (_) {
        print("Surge multiplier updated");
      });
      
      // View pricing rules
      channel.push("view_pricing_rules", payload: {})
        .receive("ok", (rules) {
          print("Active pricing rules: ${rules.length}");
        });
      
      // Listen for pricing updates
      channel.on("pricing_update", (payload) {
        print("Pricing changed: ${payload['reason']}");
      });
    });
}
```

#### Offline Operations Channel Test
```dart
void testOfflineOperationsChannel() {
  final channel = socket.channel("offline:device:device_mobile_123");
  
  channel.join()
    .receive("ok", (_) {
      // Queue request for offline sync
      channel.push("queue_request", payload: {
        "request_type": "create_ride_request",
        "data": {
          "pickup": "123 Main St",
          "dropoff": "456 Park Ave"
        }
      }).receive("ok", (queued) {
        print("Request queued with ID: ${queued['queue_id']}");
      });
      
      // Sync data when online
      channel.push("sync_data", payload: {
        "pending_requests": 5
      }).receive("ok", (synced) {
        print("Synced ${synced['count']} requests");
      });
      
      // Get offline cache
      channel.push("offline_available_buses", payload: {
        "pickup_lat": 40.7128,
        "pickup_lng": -74.0060
      }).receive("ok", (buses) {
        print("Cached buses: ${buses.length}");
      });
      
      // Listen for sync status
      channel.on("sync_status", (payload) {
        print("Sync status: ${payload['status']}");
      });
    });
}
```

#### Integration Channel Test
```dart
void testIntegrationChannel() {
  final channel = socket.channel("integration:system");
  
  channel.join()
    .receive("ok", (_) {
      // Maps API call
      channel.push("maps_api_call", payload: {
        "api_endpoint": "directions",
        "origin": "40.7128,-74.0060",
        "destination": "40.7580,-73.9855"
      }).receive("ok", (result) {
        print("Route duration: ${result['duration']} seconds");
      });
      
      // Payment gateway integration
      channel.push("payment_gateway", payload: {
        "gateway": "stripe",
        "amount": 25.50,
        "currency": "USD"
      }).receive("ok", (payment) {
        print("Payment ID: ${payment['payment_id']}");
      });
      
      // Send SMS
      channel.push("send_sms", payload: {
        "phone": "+1234567890",
        "message": "Your bus is arriving in 5 minutes"
      }).receive("ok", (_) {
        print("SMS sent");
      });
      
      // Send push notification
      channel.push("push_notification", payload: {
        "user_id": "user_123",
        "title": "Bus Arrived",
        "body": "Your bus has arrived at the stop"
      }).receive("ok", (_) {
        print("Push notification sent");
      });
      
      // Listen for webhook events
      channel.on("webhook_event", (payload) {
        print("Webhook received: ${payload['event_type']}");
      });
    });
}
```

---

## Development

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
