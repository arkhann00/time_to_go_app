class OutreachTestimony {
  final int id;
  final String text;

  const OutreachTestimony({required this.id, required this.text});

  factory OutreachTestimony.fromMap(Map<String, dynamic> map) =>
      OutreachTestimony(
        id: (map['id'] as num?)?.toInt() ?? 0,
        text: (map['text'] as String? ?? '').trim(),
      );
}

class OutreachStatEntry {
  final int id;
  final int userId;
  final int gospelsTold;
  final int salvationPrayedUnreachable;
  final int scripturesDistributed;
  final int fathersLettersDistributed;
  final int healingsDeliverances;
  final List<OutreachTestimony> testimonies;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userName;
  final String? userAvatarUrl;

  const OutreachStatEntry({
    required this.id,
    required this.userId,
    required this.gospelsTold,
    required this.salvationPrayedUnreachable,
    required this.scripturesDistributed,
    required this.fathersLettersDistributed,
    required this.healingsDeliverances,
    required this.createdAt,
    required this.updatedAt,
    this.testimonies = const [],
    this.userName = '',
    this.userAvatarUrl,
  });

  factory OutreachStatEntry.fromMap(Map<String, dynamic> map) {
    final user = map['user'] as Map<String, dynamic>? ?? {};
    return OutreachStatEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      userId: (map['user_id'] as num?)?.toInt() ?? 0,
      gospelsTold: (map['gospels_told'] as num?)?.toInt() ?? 0,
      salvationPrayedUnreachable:
          (map['salvation_prayed_unreachable'] as num?)?.toInt() ?? 0,
      scripturesDistributed:
          (map['scriptures_distributed'] as num?)?.toInt() ?? 0,
      fathersLettersDistributed:
          (map['fathers_letters_distributed'] as num?)?.toInt() ?? 0,
      healingsDeliverances:
          (map['healings_deliverances'] as num?)?.toInt() ?? 0,
      testimonies:
          (map['testimonies'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(OutreachTestimony.fromMap)
              .where((testimony) => testimony.text.isNotEmpty)
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      userName: (user['name'] as String? ?? '').trim(),
      userAvatarUrl: user['avatar_url'] as String?,
    );
  }
}

class SummaryStats {
  final int totalSalvation;
  final int totalSaved;
  final int contactsTaken;
  final int scripturesDistributed;
  final int fathersLettersDistributed;
  final int healingsDeliverances;

  const SummaryStats({
    this.totalSalvation = 0,
    this.totalSaved = 0,
    this.contactsTaken = 0,
    this.scripturesDistributed = 0,
    this.fathersLettersDistributed = 0,
    this.healingsDeliverances = 0,
  });

  factory SummaryStats.fromMap(Map<String, dynamic> map) => SummaryStats(
    totalSalvation: (map['total_heard_gospel'] as num?)?.toInt() ?? 0,
    totalSaved: (map['total_saved'] as num?)?.toInt() ?? 0,
    contactsTaken: (map['contacts_taken'] as num?)?.toInt() ?? 0,
    scripturesDistributed:
        (map['scriptures_distributed'] as num?)?.toInt() ?? 0,
    fathersLettersDistributed:
        (map['fathers_letters_distributed'] as num?)?.toInt() ?? 0,
    healingsDeliverances: (map['healings_deliverances'] as num?)?.toInt() ?? 0,
  );
}
