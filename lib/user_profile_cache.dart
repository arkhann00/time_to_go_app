import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api.dart';

/// Persists account profile (name, email, about, avatar) for offline access.
class UserProfileCache {
  static const _userJsonKey = 'cached_backend_user_v1';
  static const _avatarPathKey = 'cached_avatar_path_v1';
  static const _avatarUrlKey = 'cached_avatar_url_v1';
  static const _avatarFileName = 'profile_avatar.jpg';

  Future<String?> loadUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userJsonKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  Future<void> saveUserJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userJsonKey, json);
  }

  Future<String?> loadAvatarLocalPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_avatarPathKey);
    if (path == null || path.isEmpty) return null;
    if (!File(path).existsSync()) {
      await prefs.remove(_avatarPathKey);
      return null;
    }
    return path;
  }

  Future<String?> syncAvatar({
    required String? avatarUrl,
    required BackendApi api,
    required String? Function(String? raw) resolveUrl,
  }) async {
    final normalizedUrl = (avatarUrl ?? '').trim();
    if (normalizedUrl.isEmpty) {
      await _removeAvatarFile();
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedUrl = prefs.getString(_avatarUrlKey);
    final cachedPath = await loadAvatarLocalPath();
    if (cachedUrl == normalizedUrl && cachedPath != null) {
      return cachedPath;
    }

    final networkUrl = resolveUrl(normalizedUrl);
    if (networkUrl == null || networkUrl.isEmpty) {
      return cachedPath;
    }

    try {
      final bytes = await api.downloadBytes(networkUrl);
      if (bytes.isEmpty) return cachedPath;

      final file = await _avatarFile();
      await file.writeAsBytes(bytes, flush: true);
      await prefs.setString(_avatarPathKey, file.path);
      await prefs.setString(_avatarUrlKey, normalizedUrl);
      return file.path;
    } catch (_) {
      return cachedPath;
    }
  }

  Future<String?> saveAvatarFromLocalFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync()) return loadAvatarLocalPath();

    final file = await _avatarFile();
    await source.copy(file.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, file.path);
    await prefs.remove(_avatarUrlKey);
    return file.path;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userJsonKey);
    await prefs.remove(_avatarPathKey);
    await prefs.remove(_avatarUrlKey);
    await _removeAvatarFile();
  }

  Future<File> _avatarFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_avatarFileName');
  }

  Future<void> _removeAvatarFile() async {
    try {
      final file = await _avatarFile();
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}
