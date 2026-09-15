class LatestTestimony {
  final String text;
  final String? author;
  final String? addedByName;
  final String? addedByAvatarUrl;
  final DateTime createdAt;

  const LatestTestimony({
    required this.text,
    required this.author,
    required this.createdAt,
    this.addedByName,
    this.addedByAvatarUrl,
  });
}

class UserProfile {
  final String name;
  final String contact;
  final String church;
  final String bio;

  const UserProfile({
    required this.name,
    required this.contact,
    required this.church,
    required this.bio,
  });

  factory UserProfile.empty() =>
      const UserProfile(name: '', contact: '', church: '', bio: '');

  bool get isEmpty =>
      name.isEmpty && contact.isEmpty && church.isEmpty && bio.isEmpty;

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  UserProfile copyWith({
    String? name,
    String? contact,
    String? church,
    String? bio,
  }) => UserProfile(
    name: name ?? this.name,
    contact: contact ?? this.contact,
    church: church ?? this.church,
    bio: bio ?? this.bio,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'contact': contact,
    'church': church,
    'bio': bio,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    name: map['name'] as String? ?? '',
    contact: map['contact'] as String? ?? '',
    church: map['church'] as String? ?? '',
    bio: map['bio'] as String? ?? '',
  );
}

class BackendUser {
  final int id;
  final String name;
  final String email;
  final String avatarUrl;
  final String about;

  const BackendUser({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.about,
  });

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    return (list.first[0] + (list.length > 1 ? list.last[0] : ''))
        .toUpperCase();
  }

  factory BackendUser.fromMap(Map<String, dynamic> map) => BackendUser(
    id: (map['id'] as num?)?.toInt() ?? 0,
    name: (map['name'] as String? ?? '').trim(),
    email: (map['email'] as String? ?? '').trim(),
    avatarUrl: (map['avatar_url'] as String? ?? '').trim(),
    about: (map['about'] as String? ?? '').trim(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar_url': avatarUrl,
    'about': about,
  };
}
