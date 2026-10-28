/// Data models for the rider status / group detail screen.
///
/// These mirror the DB tables that the status screen needs:
///   • ride_requests  — for the current rider's request status
///   • ride_groups    — for the group summary (fare, depart_at, driver)
///   • group_members  — for pickup/drop-off order and fare
///   • my_group_co_riders view — first-name-only co-rider list
///   • drivers + users — for driver name / car details

library;

// ── Group status ────────────────────────────────────────────────────────────

/// Mirrors the `group_status` Postgres enum (including values from all
/// migrations: 001 + 006 + 010 + 012).
enum GroupStatus {
  open,
  forming,
  pendingDriver,
  driverAssigned,
  confirmed,
  inProgress,
  completed,
  cancelled;

  static GroupStatus fromString(String v) => switch (v) {
        'open'            => open,
        'forming'         => forming,
        'pending_driver'  => pendingDriver,
        'driver_assigned' => driverAssigned,
        'confirmed'       => confirmed,
        'in_progress'     => inProgress,
        'completed'       => completed,
        'cancelled'       => cancelled,
        _                 => pendingDriver,
      };

  String get label => switch (this) {
        open            => 'Group open',
        forming         => 'Finding riders',
        pendingDriver   => 'Finding driver',
        driverAssigned  => 'Driver assigned',
        confirmed       => 'Confirmed',
        inProgress      => 'On the way',
        completed       => 'Completed',
        cancelled       => 'Cancelled',
      };
}

// ── Co-rider (from my_group_co_riders view) ─────────────────────────────────

class CoRider {
  const CoRider({
    required this.requestId,
    required this.firstName,
    required this.pickupOrder,
    required this.dropoffOrder,
    required this.fare,
  });

  final String requestId;
  final String firstName;
  final int pickupOrder;
  final int dropoffOrder;
  final double fare;

  factory CoRider.fromJson(Map<String, dynamic> j) => CoRider(
        requestId:    j['request_id'] as String,
        firstName:    j['first_name'] as String,
        pickupOrder:  j['pickup_order'] as int,
        dropoffOrder: j['dropoff_order'] as int,
        fare:         (j['fare'] as num).toDouble(),
      );
}

// ── Driver detail (from drivers + users join) ─────────────────────────────────

class DriverDetail {
  const DriverDetail({
    required this.firstName,
    required this.carModel,
    required this.plate,
    required this.rating,
  });

  final String firstName;
  final String carModel;
  final String plate;
  final double rating;

  factory DriverDetail.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String? ?? '';
    final firstName = name.contains(' ')
        ? name.substring(0, name.indexOf(' '))
        : name;
    return DriverDetail(
      firstName: firstName.isEmpty ? 'Driver' : firstName,
      carModel:  j['car_model'] as String? ?? '',
      plate:     j['plate'] as String? ?? '',
      rating:    (j['rating'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

// ── Full group detail ─────────────────────────────────────────────────────────

class GroupDetail {
  const GroupDetail({
    required this.groupId,
    required this.status,
    required this.departAt,
    required this.fareTotal,
    required this.myFare,
    required this.myPickupOrder,
    required this.coRiders,
    this.driver,
    this.cutoffAt,
    this.currentFare,
  });

  final String groupId;
  final GroupStatus status;
  final DateTime departAt;
  final double fareTotal;
  /// The current rider's locked fare from group_members.fare
  final double myFare;
  final int myPickupOrder;
  /// Other riders in the group (first name only).
  final List<CoRider> coRiders;
  /// Null until a driver is assigned.
  final DriverDetail? driver;
  /// Cutoff timestamp when open group locks fare and transitions to pending_driver.
  final DateTime? cutoffAt;
  /// Current per-rider price for open groups (can drop as riders join).
  final double? currentFare;

  /// Effective price to display to rider (current_fare if open, else myFare).
  double get displayFare => currentFare ?? myFare;

  /// Total rider count = coRiders + 1 (self).
  int get riderCount => coRiders.length + 1;
}
