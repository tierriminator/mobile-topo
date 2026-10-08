/// App settings for Mobile Topo

/// Unit lengths are shown and edited in. Lengths are always stored in meters.
enum LengthUnit {
  meters(1, 'm'),
  feet(0.3048, 'ft');

  const LengthUnit(this.inMeters, this.symbol);

  /// Length of one unit in meters
  final double inMeters;
  final String symbol;

  double fromMeters(num value) => value / inMeters;
  double toMeters(num value) => value * inMeters;
}

/// Unit angles are shown and edited in. Angles are always stored in degrees.
enum AngleUnit {
  degrees(360, '°'),
  grad(400, 'g');

  const AngleUnit(this.fullCircle, this.symbol);

  /// Number of units in a full circle
  final double fullCircle;
  final String symbol;

  double fromDegrees(num value) => value * fullCircle / 360;
  double toDegrees(num value) => value * 360 / fullCircle;
}

enum ShotDirection { forward, backward }

class Settings {
  final bool smartModeEnabled;
  final ShotDirection shotDirection;
  final LengthUnit lengthUnit;
  final AngleUnit angleUnit;
  final bool showGrid;
  final bool autoConnect;
  final String? lastConnectedDeviceAddress;
  final String? lastConnectedDeviceName;
  final String? lastSelectedCaveId;
  final String? lastSelectedSectionId;

  const Settings({
    this.smartModeEnabled = true,
    this.shotDirection = ShotDirection.forward,
    this.lengthUnit = LengthUnit.meters,
    this.angleUnit = AngleUnit.degrees,
    this.showGrid = true,
    this.autoConnect = false,
    this.lastConnectedDeviceAddress,
    this.lastConnectedDeviceName,
    this.lastSelectedCaveId,
    this.lastSelectedSectionId,
  });

  Settings copyWith({
    bool? smartModeEnabled,
    ShotDirection? shotDirection,
    LengthUnit? lengthUnit,
    AngleUnit? angleUnit,
    bool? showGrid,
    bool? autoConnect,
    String? lastConnectedDeviceAddress,
    String? lastConnectedDeviceName,
    String? lastSelectedCaveId,
    String? lastSelectedSectionId,
  }) {
    return Settings(
      smartModeEnabled: smartModeEnabled ?? this.smartModeEnabled,
      shotDirection: shotDirection ?? this.shotDirection,
      lengthUnit: lengthUnit ?? this.lengthUnit,
      angleUnit: angleUnit ?? this.angleUnit,
      showGrid: showGrid ?? this.showGrid,
      autoConnect: autoConnect ?? this.autoConnect,
      lastConnectedDeviceAddress:
          lastConnectedDeviceAddress ?? this.lastConnectedDeviceAddress,
      lastConnectedDeviceName:
          lastConnectedDeviceName ?? this.lastConnectedDeviceName,
      lastSelectedCaveId: lastSelectedCaveId ?? this.lastSelectedCaveId,
      lastSelectedSectionId:
          lastSelectedSectionId ?? this.lastSelectedSectionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'smartModeEnabled': smartModeEnabled,
        'shotDirection': shotDirection.name,
        'lengthUnit': lengthUnit.name,
        'angleUnit': angleUnit.name,
        'showGrid': showGrid,
        'autoConnect': autoConnect,
        'lastConnectedDeviceAddress': lastConnectedDeviceAddress,
        'lastConnectedDeviceName': lastConnectedDeviceName,
        'lastSelectedCaveId': lastSelectedCaveId,
        'lastSelectedSectionId': lastSelectedSectionId,
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
        autoConnect: json['autoConnect'] as bool? ?? true,
        lastConnectedDeviceAddress: json['lastConnectedDeviceAddress'] as String?,
        lastConnectedDeviceName: json['lastConnectedDeviceName'] as String?,
        lastSelectedCaveId: json['lastSelectedCaveId'] as String?,
        lastSelectedSectionId: json['lastSelectedSectionId'] as String?,
      );
}
