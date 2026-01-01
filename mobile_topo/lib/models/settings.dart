/// App settings for Mobile Topo

enum LengthUnit { meters, feet }

enum AngleUnit { degrees, grad }

enum ShotDirection { forward, backward }

class Settings {
  final bool smartModeEnabled;
  final ShotDirection shotDirection;
  final LengthUnit lengthUnit;
  final AngleUnit angleUnit;
  final bool showGrid;
  final bool autoConnect;

  const Settings({
    this.smartModeEnabled = true,
    this.shotDirection = ShotDirection.forward,
    this.lengthUnit = LengthUnit.meters,
    this.angleUnit = AngleUnit.degrees,
    this.showGrid = true,
    this.autoConnect = false,
  });

  Settings copyWith({
    bool? smartModeEnabled,
    ShotDirection? shotDirection,
    LengthUnit? lengthUnit,
    AngleUnit? angleUnit,
    bool? showGrid,
    bool? autoConnect,
  }) {
    return Settings(
      smartModeEnabled: smartModeEnabled ?? this.smartModeEnabled,
      shotDirection: shotDirection ?? this.shotDirection,
      lengthUnit: lengthUnit ?? this.lengthUnit,
      angleUnit: angleUnit ?? this.angleUnit,
      showGrid: showGrid ?? this.showGrid,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }

  Map<String, dynamic> toJson() => {
        'smartModeEnabled': smartModeEnabled,
        'shotDirection': shotDirection.name,
        'lengthUnit': lengthUnit.name,
        'angleUnit': angleUnit.name,
        'showGrid': showGrid,
        'autoConnect': autoConnect,
      };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        smartModeEnabled: json['smartModeEnabled'] as bool? ?? true,
        shotDirection: ShotDirection.values.firstWhere(
          (e) => e.name == json['shotDirection'],
          orElse: () => ShotDirection.forward,
        ),
        lengthUnit: LengthUnit.values.firstWhere(
          (e) => e.name == json['lengthUnit'],
          orElse: () => LengthUnit.meters,
        ),
        angleUnit: AngleUnit.values.firstWhere(
          (e) => e.name == json['angleUnit'],
          orElse: () => AngleUnit.degrees,
        ),
        showGrid: json['showGrid'] as bool? ?? true,
        autoConnect: json['autoConnect'] as bool? ?? false,
      );
}
