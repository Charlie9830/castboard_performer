class UnderstudySessionModel {
  final String id;
  final DateTime connectionTimestamp;
  final bool active;
  final String clientIPAddress;
  final String userAgentString;

  UnderstudySessionModel({
    required this.id,
    required this.connectionTimestamp,
    required this.active,
    required this.clientIPAddress,
    required this.userAgentString,
  });

  UnderstudySessionModel copyWith({
    String? id,
    DateTime? connectionTimestamp,
    bool? active,
    String? clientIPAddress,
    String? userAgentString,
  }) {
    return UnderstudySessionModel(
      id: id ?? this.id,
      connectionTimestamp: connectionTimestamp ?? this.connectionTimestamp,
      active: active ?? this.active,
      clientIPAddress: clientIPAddress ?? this.clientIPAddress,
      userAgentString: userAgentString ?? this.userAgentString,
    );
  }
}
