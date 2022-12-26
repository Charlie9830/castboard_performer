class UnderstudySessionModel {
  final String id;
  final DateTime connectionTimestamp;
  final bool active;
  final String userAgent;

  UnderstudySessionModel({
    required this.id,
    required this.connectionTimestamp,
    required this.active,
    required this.userAgent,
  });

  UnderstudySessionModel copyWith({
    String? id,
    DateTime? connectionTimestamp,
    bool? active,
    String? userAgent,
  }) {
    return UnderstudySessionModel(
      id: id ?? this.id,
      connectionTimestamp: connectionTimestamp ?? this.connectionTimestamp,
      active: active ?? this.active,
      userAgent: userAgent ?? this.userAgent,
    );
  }
}
