import 'package:latlong2/latlong.dart';

import '../../core/models/app_enums.dart';

class NewBeliever {
  final String id;
  final int? remoteId;
  final String name;
  final String telegram;
  final String phone;
  final String testimony;
  final String note;
  final EvangelismMethod evangelismMethod;
  final String customEvangelismMethod;
  final DateTime createdAt;
  final BelieverStage stage;
  final double? latitude;
  final double? longitude;
  final String? place;

  const NewBeliever({
    required this.id,
    this.remoteId,
    required this.name,
    required this.telegram,
    required this.phone,
    required this.testimony,
    required this.note,
    required this.evangelismMethod,
    required this.customEvangelismMethod,
    required this.createdAt,
    required this.stage,
    this.latitude,
    this.longitude,
    this.place,
  });

  bool get hasLocation => latitude != null && longitude != null;
  LatLng? get latLng => hasLocation ? LatLng(latitude!, longitude!) : null;

  NewBeliever copyWith({
    String? id,
    int? remoteId,
    String? name,
    String? telegram,
    String? phone,
    String? testimony,
    String? note,
    EvangelismMethod? evangelismMethod,
    String? customEvangelismMethod,
    DateTime? createdAt,
    BelieverStage? stage,
    double? latitude,
    double? longitude,
    String? place,
    bool clearLocation = false,
  }) => NewBeliever(
    id: id ?? this.id,
    remoteId: remoteId ?? this.remoteId,
    name: name ?? this.name,
    telegram: telegram ?? this.telegram,
    phone: phone ?? this.phone,
    testimony: testimony ?? this.testimony,
    note: note ?? this.note,
    evangelismMethod: evangelismMethod ?? this.evangelismMethod,
    customEvangelismMethod:
        customEvangelismMethod ?? this.customEvangelismMethod,
    createdAt: createdAt ?? this.createdAt,
    stage: stage ?? this.stage,
    latitude: clearLocation ? null : (latitude ?? this.latitude),
    longitude: clearLocation ? null : (longitude ?? this.longitude),
    place: clearLocation ? null : (place ?? this.place),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    if (remoteId != null) 'remoteId': remoteId,
    'name': name,
    'telegram': telegram,
    'phone': phone,
    'testimony': testimony,
    'note': note,
    'evangelismMethod': evangelismMethod.name,
    'customEvangelismMethod': customEvangelismMethod,
    'createdAt': createdAt.toIso8601String(),
    'stage': stage.name,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (place != null && place!.isNotEmpty) 'place': place,
  };

  factory NewBeliever.fromMap(Map<String, dynamic> map) => NewBeliever(
    id: map['id'] as String,
    remoteId: (map['remoteId'] as num?)?.toInt(),
    name: map['name'] as String? ?? '',
    telegram: map['telegram'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    testimony: map['testimony'] as String? ?? '',
    note: map['note'] as String? ?? '',
    evangelismMethod: EvangelismMethod.values.firstWhere(
      (method) => method.name == map['evangelismMethod'],
      orElse: () => EvangelismMethod.fourSigns,
    ),
    customEvangelismMethod: map['customEvangelismMethod'] as String? ?? '',
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    stage: BelieverStage.values.firstWhere(
      (stage) => stage.name == map['stage'],
      orElse: () => BelieverStage.interested,
    ),
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    place: map['place'] as String?,
  );
}
