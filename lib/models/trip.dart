/// A surveying event: values common to all measurements taken during it.
/// Measurements refer to their trip by [id].
class Trip {
  final String id;
  final DateTime date;

  /// Angle from map north to magnetic north in degrees, positive when
  /// magnetic north lies east of map north. It is added to the azimuth of
  /// every stretch of this trip when positions are computed.
  final num declination;

  /// Further information like the people involved or the cave's condition
  final String comment;

  /// When the trip was created; the most recently created trip is the one
  /// new measurements are assigned to
  final DateTime createdAt;

  const Trip({
    required this.id,
    required this.date,
    this.declination = 0,
    this.comment = '',
    required this.createdAt,
  });

  Trip copyWith({
    DateTime? date,
    num? declination,
    String? comment,
  }) {
    return Trip(
      id: id,
      date: date ?? this.date,
      declination: declination ?? this.declination,
      comment: comment ?? this.comment,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'declination': declination,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        declination: json['declination'] as num? ?? 0,
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
