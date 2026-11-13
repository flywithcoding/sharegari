/// Data model for the user profile row in `public.users`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.rating,
    required this.ratingCount,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final double rating;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Returns user initials (e.g. "Mohammad Abir" -> "MA", "Abir" -> "A").
  String get initials {
    final clean = fullName.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawName = (json['full_name'] as String?) ??
        (json['name'] as String?) ??
        'User';
    return UserProfile(
      id: json['id'] as String,
      fullName: rawName,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: (json['role'] as String?) ?? 'rider',
      rating: ((json['rating'] as num?) ?? 5.0).toDouble(),
      ratingCount: (json['rating_count'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? role,
    double? rating,
    int? ratingCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Aggregated user ride statistics computed from `ride_requests`.
class UserRideStats {
  const UserRideStats({
    required this.totalRequests,
    required this.completedRides,
    required this.cancelledRides,
  });

  final int totalRequests;
  final int completedRides;
  final int cancelledRides;

  static const zero = UserRideStats(
    totalRequests: 0,
    completedRides: 0,
    cancelledRides: 0,
  );
}
