import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backend_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  await initializeDateFormatting('en_US', null);
  runApp(const TimeToGoApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum AppLanguage { ru, en }

enum AppThemeMode { system, light, dark }

enum BelieverStage {
  interested,
  receivedJesus,
  joinedCommunity,
  baptised,
  evangelist,
}

enum EvangelismMethod { fourSigns, jesusAtDoor, custom }

// ─────────────────────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────────────────────

class TimeToGoApp extends StatefulWidget {
  const TimeToGoApp({super.key});
  @override
  State<TimeToGoApp> createState() => _TimeToGoAppState();
}

class _TimeToGoAppState extends State<TimeToGoApp> {
  static const _themeKey = 'app_theme_mode';
  static const _langKey = 'app_language';
  static const _tokenKey = 'api_access_token_v1';
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://5.42.113.18:8000',
  );
  static const _apiAccessToken = String.fromEnvironment('API_ACCESS_TOKEN');

  late final BackendApi _backendApi;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppLanguage _language = AppLanguage.ru;
  String? _accessToken;
  bool _continueOffline = false;
  bool _migrateLocalOnNextAuth = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _backendApi = BackendApi(baseUrl: _apiBaseUrl);
    _load();
  }

  @override
  void dispose() {
    _backendApi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ti = prefs.getInt(_themeKey);
    final lv = prefs.getString(_langKey);
    final storedToken = prefs.getString(_tokenKey);
    if (ti != null && ti >= 0 && ti < AppThemeMode.values.length) {
      _themeMode = AppThemeMode.values[ti];
    }
    if (lv == 'en') _language = AppLanguage.en;
    _accessToken = (storedToken != null && storedToken.isNotEmpty)
        ? storedToken
        : (_apiAccessToken.isEmpty ? null : _apiAccessToken);
    _backendApi.setAccessToken(_accessToken);
    setState(() => _ready = true);
  }

  Future<void> _onAuthSuccess(String token, bool migrateLocal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _backendApi.setAccessToken(token);
    setState(() {
      _accessToken = token;
      _continueOffline = false;
      _migrateLocalOnNextAuth = migrateLocal;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _backendApi.setAccessToken(null);
    setState(() {
      _accessToken = null;
      _continueOffline = false;
      _migrateLocalOnNextAuth = false;
    });
  }

  void _continueWithoutAuth() {
    setState(() => _continueOffline = true);
  }

  void _openAuth() {
    setState(() => _continueOffline = false);
  }

  Future<void> _setTheme(AppThemeMode m) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_themeKey, m.index);
    setState(() => _themeMode = m);
  }

  Future<void> _setLang(AppLanguage l) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_langKey, l.name);
    setState(() => _language = l);
  }

  ThemeMode get _fm => switch (_themeMode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: S(_language).appTitle,
      themeMode: _fm,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: (_accessToken == null && !_continueOffline)
          ? AuthScreen(
              language: _language,
              backendApi: _backendApi,
              onAuthSuccess: _onAuthSuccess,
              onContinueOffline: _continueWithoutAuth,
            )
          : HomeScreen(
              language: _language,
              themeMode: _themeMode,
              onTheme: _setTheme,
              onLang: _setLang,
              backendApi: _backendApi,
              isAuthenticated: _accessToken != null,
              migrateLocalOnAuth: _migrateLocalOnNextAuth,
              onMigrationHandled: () {
                if (_migrateLocalOnNextAuth) {
                  setState(() => _migrateLocalOnNextAuth = false);
                }
              },
              onOpenAuth: _openAuth,
              onLogout: _logout,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final seed = isDark ? const Color(0xFFD9772A) : const Color(0xFFB85C12);
  final bg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F4EF);
  final cardColor = isDark ? const Color(0xFF1C1C1C) : Colors.white;
  final borderColor = isDark
      ? Colors.white.withOpacity(0.07)
      : Colors.black.withOpacity(0.06);
  final inputFill = isDark ? const Color(0xFF1E1E1E) : Colors.white;
  final inputBorder = isDark
      ? Colors.white.withOpacity(0.08)
      : Colors.black.withOpacity(0.08);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: seed,
      surface: bg,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : const Color(0xFF1A1008),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: seed, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.12)
          : Colors.black.withOpacity(0.88),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  final AppLanguage language;
  final BackendApi backendApi;
  final void Function(String token, bool migrateLocal) onAuthSuccess;
  final VoidCallback onContinueOffline;
  const AuthScreen({
    super.key,
    required this.language,
    required this.backendApi,
    required this.onAuthSuccess,
    required this.onContinueOffline,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  int _tab = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _submit() async {
    final tr = S(widget.language);
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();

    if (_tab == 1 && name.isEmpty) {
      setState(() => _error = tr.nameReq);
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = tr.authInvalidEmail);
      return;
    }
    if (password.length < 6) {
      setState(() => _error = tr.authPasswordRule);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_tab == 1) {
        await widget.backendApi.register(
          name: name,
          email: email,
          password: password,
        );
      }
      final token = await widget.backendApi.login(
        email: email,
        password: password,
      );
      if (token.isEmpty) {
        setState(() => _error = tr.authUnknownError);
        return;
      }
      if (!mounted) return;
      widget.onAuthSuccess(token, _tab == 1);
    } on BackendApiException catch (e) {
      setState(() => _error = _humanAuthError(tr, e));
    } catch (_) {
      setState(() => _error = tr.authNetworkError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanAuthError(S tr, BackendApiException e) {
    if (e.statusCode == 409) return tr.authEmailExists;
    if (e.statusCode == 401) return tr.authWrongCredentials;
    if (e.statusCode == 422) return tr.authInvalidInput;
    if (e.message.isNotEmpty) return e.message;
    return tr.authUnknownError;
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Text(
                  tr.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr.authSub,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(tr.signIn),
                      icon: const Icon(Icons.login_rounded),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(tr.signUp),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: _busy
                      ? null
                      : (next) {
                          setState(() {
                            _tab = next.first;
                            _error = null;
                          });
                        },
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        if (_tab == 1) ...[
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: tr.yourName,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: tr.authEmail,
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: tr.authPassword,
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _submit,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _tab == 0
                                        ? Icons.login_rounded
                                        : Icons.person_add_alt_1_rounded,
                                  ),
                            label: Text(_tab == 0 ? tr.signIn : tr.signUp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : widget.onContinueOffline,
                  child: Text(tr.continueOffline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final AppLanguage language;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onTheme;
  final ValueChanged<AppLanguage> onLang;
  final BackendApi backendApi;
  final bool isAuthenticated;
  final bool migrateLocalOnAuth;
  final VoidCallback onMigrationHandled;
  final VoidCallback onOpenAuth;
  final Future<void> Function() onLogout;
  const HomeScreen({
    super.key,
    required this.language,
    required this.themeMode,
    required this.onTheme,
    required this.onLang,
    required this.backendApi,
    required this.isAuthenticated,
    required this.migrateLocalOnAuth,
    required this.onMigrationHandled,
    required this.onOpenAuth,
    required this.onLogout,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _key = 'believers_v2';
  final List<NewBeliever> _list = [];
  final Map<EvangelismMethod, int> _defaultMethodIds = {};
  final Map<String, int> _customMethodIds = {};
  BackendUser? _backendUser;
  int _heardGospelCount = 0;
  int _acceptedJesusCount = 0;
  String? _testimonyOfDay;
  String? _testimonyAuthor;
  bool _dashboardLoading = true;
  bool _loading = true;
  int _tab = 0;

  BackendApi get _backendApi => widget.backendApi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAuthenticated != widget.isAuthenticated) {
      _load();
    }
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    BackendUser? backendUser;
    final localItems = raw
        .map((e) => NewBeliever.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    var items = [...localItems]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_backendApi.hasAuth) {
      try {
        if (widget.migrateLocalOnAuth) {
          await _migrateLocalBelieversToServer(localItems);
        }
        backendUser = BackendUser.fromMap(await _backendApi.me());
        final methods = await _backendApi.getMethods();
        _cacheRemoteMethods(methods);
        final remoteBelievers = await _backendApi.getMyBelievers();
        items = remoteBelievers.map(_fromBackendBeliever).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await p.setStringList(
          _key,
          items.map((e) => jsonEncode(e.toMap())).toList(),
        );
      } catch (_) {
        // Keep local data when backend auth/token/network is unavailable.
      } finally {
        if (widget.migrateLocalOnAuth) {
          widget.onMigrationHandled();
        }
      }
    }

    final dashboard = await _loadDashboardData();

    setState(() {
      _list
        ..clear()
        ..addAll(items);
      _backendUser = backendUser;
      _heardGospelCount = dashboard.heard;
      _acceptedJesusCount = dashboard.accepted;
      _testimonyOfDay = dashboard.testimony;
      _testimonyAuthor = dashboard.author;
      _dashboardLoading = false;
      _loading = false;
    });
  }

  Future<({int heard, int accepted, String? testimony, String? author})>
  _loadDashboardData() async {
    var heard = 0;
    var accepted = 0;
    String? testimony;
    String? author;

    try {
      heard = (await _backendApi.getAllBelievers()).length;
    } catch (_) {}

    try {
      accepted = await _backendApi.getAcceptedJesusCount();
    } catch (_) {}

    try {
      final day = await _backendApi.getTestimonyOfDay();
      final text = (day['testimony'] as String? ?? '').trim();
      if (text.isNotEmpty) {
        testimony = text;
        final name = (day['name'] as String? ?? '').trim();
        author = name.isEmpty ? null : name;
      }
    } on BackendApiException catch (e) {
      if (e.statusCode == 404) testimony = null;
    } catch (_) {}

    return (
      heard: heard,
      accepted: accepted,
      testimony: testimony,
      author: author,
    );
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _key,
      _list.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(
        tr: S(widget.language),
        themeMode: widget.themeMode,
        language: widget.language,
        isAuthenticated: widget.isAuthenticated,
        onTheme: widget.onTheme,
        onLang: widget.onLang,
        onAuthAction: () async {
          if (widget.isAuthenticated) {
            await widget.onLogout();
          } else {
            widget.onOpenAuth();
          }
        },
      ),
    );
  }

  String? _resolveAvatarUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) return value;
    return _backendApi.resolveUrl(value).toString();
  }

  Future<void> _editAccountProfile() async {
    if (!_backendApi.hasAuth) return;
    final current = _backendUser;
    if (current == null) {
      try {
        final me = await _backendApi.me();
        if (!mounted) return;
        setState(() => _backendUser = BackendUser.fromMap(me));
      } catch (_) {
        return;
      }
    }
    final initial = _backendUser;
    if (initial == null) return;

    final result = await showModalBottomSheet<AccountEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AccountEditSheet(language: widget.language, initial: initial),
    );
    if (result == null) return;

    try {
      var map = await _backendApi.patchMe(
        name: result.name,
        about: result.about,
      );
      if (result.avatarPath != null && result.avatarPath!.isNotEmpty) {
        map = await _backendApi.uploadMyAvatar(result.avatarPath!);
      }
      if (!mounted) return;
      setState(() => _backendUser = BackendUser.fromMap(map));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S(widget.language).saved)));
    } on BackendApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.isEmpty ? S(widget.language).save : e.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S(widget.language).authNetworkError)),
      );
    }
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet<NewBeliever>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSheet(language: widget.language),
    );
    if (result == null) return;
    setState(() => _list.insert(0, result));
    await _save();
    await _syncCreateToBackend(result);
    final dashboard = await _loadDashboardData();
    if (!mounted) return;
    setState(() {
      _heardGospelCount = dashboard.heard;
      _acceptedJesusCount = dashboard.accepted;
      _testimonyOfDay = dashboard.testimony;
      _testimonyAuthor = dashboard.author;
    });
  }

  Future<void> _delete(NewBeliever b) async {
    setState(() => _list.removeWhere((e) => e.id == b.id));
    await _save();
    final remoteId = b.remoteId ?? int.tryParse(b.id);
    if (!_backendApi.hasAuth || remoteId == null) return;
    try {
      await _backendApi.deleteBeliever(remoteId);
    } catch (_) {
      // Local state stays source of truth when remote delete fails.
    }
    final dashboard = await _loadDashboardData();
    if (!mounted) return;
    setState(() {
      _heardGospelCount = dashboard.heard;
      _acceptedJesusCount = dashboard.accepted;
      _testimonyOfDay = dashboard.testimony;
      _testimonyAuthor = dashboard.author;
    });
  }

  Future<void> _updateStage(NewBeliever b, BelieverStage stage) async {
    final i = _list.indexWhere((e) => e.id == b.id);
    if (i == -1) return;
    setState(() => _list[i] = _list[i].copyWith(stage: stage));
    await _save();
    final remoteId = b.remoteId ?? int.tryParse(b.id);
    if (!_backendApi.hasAuth || remoteId == null) return;
    try {
      await _backendApi.patchBeliever(remoteId, {'stage': stage.name});
    } catch (_) {
      // Keep local stage update even when backend sync fails.
    }
    final dashboard = await _loadDashboardData();
    if (!mounted) return;
    setState(() {
      _heardGospelCount = dashboard.heard;
      _acceptedJesusCount = dashboard.accepted;
      _testimonyOfDay = dashboard.testimony;
      _testimonyAuthor = dashboard.author;
    });
  }

  void _cacheRemoteMethods(List<Map<String, dynamic>> methods) {
    _defaultMethodIds.clear();
    _customMethodIds.clear();
    for (final method in methods) {
      final idRaw = method['id'];
      final id = idRaw is num ? idRaw.toInt() : null;
      final name = (method['name'] as String? ?? '').trim();
      if (id == null || name.isEmpty) continue;

      final resolved = methodFromBackendName(name);
      if (resolved == EvangelismMethod.custom) {
        _customMethodIds[name] = id;
      } else {
        _defaultMethodIds[resolved] = id;
      }
    }
  }

  Future<int?> _resolveMethodId(NewBeliever believer) async {
    if (!_backendApi.hasAuth) return null;
    if (_defaultMethodIds.isEmpty && _customMethodIds.isEmpty) {
      try {
        _cacheRemoteMethods(await _backendApi.getMethods());
      } catch (_) {
        return null;
      }
    }

    if (believer.evangelismMethod == EvangelismMethod.custom) {
      final name = believer.customEvangelismMethod.trim();
      if (name.isEmpty) return null;
      final cached = _customMethodIds[name];
      if (cached != null) return cached;
      try {
        final created = await _backendApi.createMethod(name);
        final createdId = (created['id'] as num?)?.toInt();
        if (createdId != null) {
          _customMethodIds[name] = createdId;
          return createdId;
        }
      } on BackendApiException catch (e) {
        if (e.statusCode == 409) {
          try {
            _cacheRemoteMethods(await _backendApi.getMethods());
            return _customMethodIds[name];
          } catch (_) {
            return null;
          }
        }
      } catch (_) {
        return null;
      }
      return null;
    }

    return _defaultMethodIds[believer.evangelismMethod];
  }

  Future<Map<String, dynamic>?> _createBackendPayload(
    NewBeliever believer, {
    bool useFallbackLocation = false,
  }) async {
    final fallbackLat = 55.7558;
    final fallbackLng = 37.6173;
    final lat = believer.latitude ?? (useFallbackLocation ? fallbackLat : null);
    final lng =
        believer.longitude ?? (useFallbackLocation ? fallbackLng : null);
    if (lat == null || lng == null) return null;
    final methodId = await _resolveMethodId(believer);
    if (methodId == null) return null;

    return {
      'name': believer.name,
      'telegram': _extractTelegramHandle(believer.telegram),
      'phone_number': believer.phone.isEmpty ? null : believer.phone,
      'met_at': DateFormat('yyyy-MM-dd').format(believer.createdAt),
      'stage': believer.stage.name,
      'method_id': methodId,
      'note': believer.note.isEmpty ? null : believer.note,
      'testimony': believer.testimony.isEmpty ? null : believer.testimony,
      'latitude': lat,
      'longitude': lng,
    };
  }

  NewBeliever _fromBackendBeliever(Map<String, dynamic> raw) {
    final id = (raw['id'] as num?)?.toInt();
    final stageValue = raw['stage'] as String? ?? BelieverStage.interested.name;
    final stage = BelieverStage.values.firstWhere(
      (e) => e.name == stageValue,
      orElse: () => BelieverStage.interested,
    );
    final methodObj = raw['method'] as Map<String, dynamic>?;
    final methodName = (methodObj?['name'] as String? ?? '').trim();
    final method = methodFromBackendName(methodName);
    final metAtRaw = raw['met_at'] as String?;

    return NewBeliever(
      id: (id ?? DateTime.now().microsecondsSinceEpoch).toString(),
      remoteId: id,
      name: (raw['name'] as String? ?? '').trim(),
      telegram: _normalizeTelegramForStorage(raw['telegram'] as String? ?? ''),
      phone: _normalizePhoneForStorage(raw['phone_number'] as String? ?? ''),
      note: (raw['note'] as String? ?? '').trim(),
      testimony: (raw['testimony'] as String? ?? '').trim(),
      evangelismMethod: method,
      customEvangelismMethod: method == EvangelismMethod.custom
          ? methodName
          : '',
      createdAt: (metAtRaw != null && metAtRaw.isNotEmpty)
          ? DateTime.tryParse(metAtRaw) ?? DateTime.now()
          : DateTime.now(),
      stage: stage,
      latitude: (raw['latitude'] as num?)?.toDouble(),
      longitude: (raw['longitude'] as num?)?.toDouble(),
      place: null,
    );
  }

  Future<void> _syncCreateToBackend(NewBeliever localBeliever) async {
    if (!_backendApi.hasAuth) return;
    final payload = await _createBackendPayload(
      localBeliever,
      useFallbackLocation: true,
    );
    if (payload == null) return;

    try {
      final created = await _backendApi.createBeliever(payload);
      final remoteBeliever = _fromBackendBeliever(created);
      final index = _list.indexWhere((e) => e.id == localBeliever.id);
      if (index == -1) return;
      setState(() => _list[index] = remoteBeliever);
      await _save();
    } catch (_) {
      // Keep locally created believer if backend create fails.
    }
  }

  Future<void> _migrateLocalBelieversToServer(List<NewBeliever> locals) async {
    if (!_backendApi.hasAuth || locals.isEmpty) return;
    for (final believer in locals) {
      if (believer.remoteId != null) continue;
      final payload = await _createBackendPayload(
        believer,
        useFallbackLocation: true,
      );
      if (payload == null) continue;
      try {
        await _backendApi.createBeliever(payload);
      } catch (_) {
        // Continue best-effort migration for the rest of local entries.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            DashboardPage(
              tr: tr,
              heardGospelCount: _heardGospelCount,
              acceptedJesusCount: _acceptedJesusCount,
              testimonyText: _testimonyOfDay,
              testimonyAuthor: _testimonyAuthor,
              loading: _dashboardLoading,
              onSettings: _openSettings,
            ),
            BelieversPage(
              tr: tr,
              believers: _list,
              loading: _loading,
              onAdd: _add,
              onDelete: _delete,
              onStage: _updateStage,
              onSettings: _openSettings,
            ),
            EvangelismMethodsPage(tr: tr, onSettings: _openSettings),
            MapPage(tr: tr, believers: _list, onSettings: _openSettings),
            ProfilePage(
              tr: tr,
              backendUser: _backendUser,
              backendAvatarUrl: _resolveAvatarUrl(_backendUser?.avatarUrl),
              isAuthenticated: widget.isAuthenticated,
              believers: _list,
              onOpenAuth: widget.onOpenAuth,
              onEditAccount: _editAccountProfile,
              onLogout: widget.onLogout,
              onSettings: _openSettings,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.grid_view_rounded),
            label: tr.homeNav,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_alt_rounded),
            label: tr.believersNav,
          ),
          NavigationDestination(
            icon: const Icon(Icons.campaign_rounded),
            label: tr.methodsNav,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_rounded),
            label: tr.mapNav,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_circle_rounded),
            label: tr.profileNav,
          ),
        ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: Text(tr.add),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGES
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatelessWidget {
  final S tr;
  final int heardGospelCount;
  final int acceptedJesusCount;
  final String? testimonyText;
  final String? testimonyAuthor;
  final bool loading;
  final VoidCallback onSettings;
  const DashboardPage({
    super.key,
    required this.tr,
    required this.heardGospelCount,
    required this.acceptedJesusCount,
    required this.testimonyText,
    required this.testimonyAuthor,
    required this.loading,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget longMetric({
      required IconData icon,
      required String value,
      required String label,
    }) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.42),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.18),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.14),
              child: Icon(icon, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageHeader(
          title: tr.appTitle,
          subtitle: tr.homeWitnessSub,
          onSettings: onSettings,
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.16),
                      theme.colorScheme.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr.testimonyOfDay,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '“${testimonyText ?? tr.noTestimonyToday}”',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (testimonyAuthor != null &&
                        testimonyAuthor!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '— $testimonyAuthor',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Column(
                children: [
                  longMetric(
                    icon: Icons.groups_rounded,
                    value: '$heardGospelCount',
                    label: tr.heardGospelCountLabel,
                  ),
                  const SizedBox(height: 10),
                  longMetric(
                    icon: Icons.favorite_rounded,
                    value: '$acceptedJesusCount',
                    label: tr.acceptedJesusCountLabel,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class BelieversPage extends StatelessWidget {
  final S tr;
  final List<NewBeliever> believers;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<NewBeliever> onDelete;
  final void Function(NewBeliever, BelieverStage) onStage;
  final VoidCallback onSettings;
  const BelieversPage({
    super.key,
    required this.tr,
    required this.believers,
    required this.loading,
    required this.onAdd,
    required this.onDelete,
    required this.onStage,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        _PageHeader(
          title: tr.believers,
          subtitle: tr.believersSub,
          onSettings: onSettings,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BelieverStage.values
                  .map((s) => _LegendChip(stage: s, lang: tr.lang))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          tr.list,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (believers.isEmpty)
          _Empty(tr: tr, onAdd: onAdd)
        else
          ...believers.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FullCard(
                item: b,
                lang: tr.lang,
                onDelete: () => onDelete(b),
                onStage: (s) => onStage(b, s),
              ),
            ),
          ),
      ],
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onSettings;
  const PlaceholderPage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onSettings,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageHeader(title: title, onSettings: onSettings),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(icon, size: 28, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EvangelismMethodsPage extends StatefulWidget {
  final S tr;
  final VoidCallback? onSettings;
  const EvangelismMethodsPage({super.key, required this.tr, this.onSettings});

  @override
  State<EvangelismMethodsPage> createState() => _EvangelismMethodsPageState();
}

class _EvangelismMethodsPageState extends State<EvangelismMethodsPage> {
  int _methodIndex = 0;

  static const _fourSignsAsset = 'assets/four_signs.jpeg';
  static const _jesusDoor1 = 'assets/jesus_on_the_door_1.PNG';
  static const _jesusDoor2 = 'assets/jesus_on_the_door_2.PNG';

  void _openFullscreen(
    BuildContext context,
    String asset,
    String semanticLabel,
  ) {
    final tr = widget.tr;
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: fade,
            child: _FullscreenEvangelAsset(
              asset: asset,
              semanticLabel: semanticLabel,
              imageMissing: tr.imageMissing,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final theme = Theme.of(context);

    Widget methodImage(String asset, String semanticLabel) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                0.35,
              ),
              child: InkWell(
                onTap: () => _openFullscreen(context, asset, semanticLabel),
                child: Image.asset(
                  asset,
                  width: constraints.maxWidth,
                  fit: BoxFit.fitWidth,
                  semanticLabel: semanticLabel,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr.imageMissing,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageHeader(
          title: tr.methodsPageTitle,
          subtitle: tr.methodsPageSub,
          onSettings: widget.onSettings,
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: [
            ButtonSegment<int>(
              value: 0,
              label: Text(tr.methodFourSignsTab),
              icon: const Icon(Icons.draw_rounded, size: 18),
            ),
            ButtonSegment<int>(
              value: 1,
              label: Text(tr.methodJesusDoorTab),
              icon: const Icon(Icons.door_front_door_outlined, size: 18),
            ),
          ],
          selected: {_methodIndex},
          onSelectionChanged: (next) {
            final v = next.first;
            setState(() => _methodIndex = v);
          },
          showSelectedIcon: false,
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _methodIndex == 0
              ? Column(
                  key: const ValueKey('m0'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    methodImage(_fourSignsAsset, tr.methodFourSignsTab),
                  ],
                )
              : Column(
                  key: const ValueKey('m1'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    methodImage(_jesusDoor1, tr.methodJesusDoorTab),
                    const SizedBox(height: 16),
                    methodImage(_jesusDoor2, tr.methodJesusDoorTab),
                  ],
                ),
        ),
      ],
    );
  }
}

class _FullscreenEvangelAsset extends StatelessWidget {
  final String asset;
  final String semanticLabel;
  final String imageMissing;

  const _FullscreenEvangelAsset({
    required this.asset,
    required this.semanticLabel,
    required this.imageMissing,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    Widget image() => Image.asset(
      asset,
      semanticLabel: semanticLabel,
      width: width,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) => Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          imageMissing,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white70),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.92)),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: InteractiveViewer(
                    minScale: 0.85,
                    maxScale: 5,
                    clipBehavior: Clip.none,
                    child: image(),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4, end: 8),
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      foregroundColor: Colors.white,
                    ),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  final S tr;
  final AppThemeMode themeMode;
  final AppLanguage language;
  final bool isAuthenticated;
  final ValueChanged<AppThemeMode> onTheme;
  final ValueChanged<AppLanguage> onLang;
  final Future<void> Function()? onAuthAction;
  const SettingsSheet({
    super.key,
    required this.tr,
    required this.themeMode,
    required this.language,
    required this.isAuthenticated,
    required this.onTheme,
    required this.onLang,
    this.onAuthAction,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late AppThemeMode _themeMode;
  late AppLanguage _language;
  bool _authBusy = false;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _language = widget.language;
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.settings,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr.settingsSub,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.themeLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<AppThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: AppThemeMode.system,
                                label: Text(
                                  tr.sys,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                icon: const Icon(Icons.brightness_auto_rounded),
                              ),
                              ButtonSegment(
                                value: AppThemeMode.light,
                                label: Text(
                                  tr.light,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                icon: const Icon(Icons.light_mode_rounded),
                              ),
                              ButtonSegment(
                                value: AppThemeMode.dark,
                                label: Text(
                                  tr.dark,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                icon: const Icon(Icons.dark_mode_rounded),
                              ),
                            ],
                            selected: {_themeMode},
                            onSelectionChanged: (v) {
                              setState(() => _themeMode = v.first);
                              widget.onTheme(v.first);
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            tr.langLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<AppLanguage>(
                            segments: const [
                              ButtonSegment(
                                value: AppLanguage.ru,
                                label: Text(
                                  'Русский',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              ButtonSegment(
                                value: AppLanguage.en,
                                label: Text(
                                  'English',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            selected: {_language},
                            onSelectionChanged: (v) {
                              setState(() => _language = v.first);
                              widget.onLang(v.first);
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            tr.account,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: widget.onAuthAction == null
                                ? const SizedBox.shrink()
                                : FilledButton.icon(
                                    onPressed: _authBusy
                                        ? null
                                        : () async {
                                            setState(() => _authBusy = true);
                                            Navigator.of(context).pop();
                                            try {
                                              await widget.onAuthAction!.call();
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _authBusy = false,
                                                );
                                              }
                                            }
                                          },
                                    icon: Icon(
                                      widget.isAuthenticated
                                          ? Icons.logout_rounded
                                          : Icons.login_rounded,
                                    ),
                                    label: Text(
                                      widget.isAuthenticated
                                          ? tr.signOut
                                          : tr.signIn,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final S tr;
  final BackendUser? backendUser;
  final String? backendAvatarUrl;
  final bool isAuthenticated;
  final List<NewBeliever> believers;
  final VoidCallback onOpenAuth;
  final Future<void> Function() onEditAccount;
  final Future<void> Function() onLogout;
  final VoidCallback onSettings;
  const ProfilePage({
    super.key,
    required this.tr,
    required this.backendUser,
    required this.backendAvatarUrl,
    required this.isAuthenticated,
    required this.believers,
    required this.onOpenAuth,
    required this.onEditAccount,
    required this.onLogout,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = believers.length;
    final savedCount = believers
        .where((b) => b.stage != BelieverStage.interested)
        .length;

    Widget statCard({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> confirmLogout() async {
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr.signOutConfirmTitle),
          content: Text(tr.signOutConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr.signOut),
            ),
          ],
        ),
      );
      if (shouldLogout == true) {
        await onLogout();
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _PageHeader(
          title: tr.profile,
          subtitle: tr.profileSub,
          onSettings: onSettings,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: !isAuthenticated
                ? Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.12,
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr.profileNeedAuth,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr.profileNeedAuthSub,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: onOpenAuth,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(tr.signIn),
                      ),
                    ],
                  )
                : backendUser == null
                ? Column(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: theme.colorScheme.error.withOpacity(
                          0.12,
                        ),
                        child: Icon(
                          Icons.cloud_off_rounded,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr.serverAccountUnavailable,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: confirmLogout,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(tr.signOut),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            tr.serverAccount,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: tr.editAccountProfile,
                            onPressed: () async {
                              await onEditAccount();
                            },
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: tr.signOut,
                            onPressed: confirmLogout,
                            icon: const Icon(Icons.logout_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.12,
                        ),
                        foregroundImage: (backendAvatarUrl != null)
                            ? NetworkImage(backendAvatarUrl!)
                            : null,
                        child: backendAvatarUrl == null
                            ? Text(
                                backendUser!.initials,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        backendUser!.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        backendUser!.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (backendUser!.about.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            backendUser!.about,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        if (isAuthenticated) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              statCard(
                icon: Icons.favorite_rounded,
                value: '$total',
                label: tr.total,
              ),
              const SizedBox(width: 10),
              statCard(
                icon: Icons.auto_awesome_rounded,
                value: '$savedCount',
                label: tr.savedPeople,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class AccountEditResult {
  final String name;
  final String about;
  final String? avatarPath;

  const AccountEditResult({
    required this.name,
    required this.about,
    this.avatarPath,
  });
}

class AccountEditSheet extends StatefulWidget {
  final AppLanguage language;
  final BackendUser initial;
  const AccountEditSheet({
    super.key,
    required this.language,
    required this.initial,
  });

  @override
  State<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<AccountEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _about;
  XFile? _avatarFile;
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _about = TextEditingController(text: widget.initial.about);
  }

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => _pickingAvatar = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file != null) {
        setState(() => _avatarFile = file);
      }
    } finally {
      if (mounted) setState(() => _pickingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                mq.viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.editAccountProfile,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          foregroundImage: _avatarFile != null
                              ? FileImage(File(_avatarFile!.path))
                              : null,
                          child: _avatarFile == null
                              ? Text(widget.initial.initials)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _pickingAvatar ? null : _pickAvatar,
                          icon: _pickingAvatar
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_library_outlined),
                          label: Text(tr.changeAvatar),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: tr.yourName,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? tr.nameReq : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _about,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: tr.about,
                        hintText: tr.bioHint,
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 44),
                          child: Icon(Icons.auto_awesome_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.of(context).pop(
                            AccountEditResult(
                              name: _name.text.trim(),
                              about: _about.text.trim(),
                              avatarPath: _avatarFile?.path,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: Text(tr.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileEditSheet extends StatefulWidget {
  final AppLanguage language;
  final UserProfile initial;
  const ProfileEditSheet({
    super.key,
    required this.language,
    required this.initial,
  });
  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _church;
  late final TextEditingController _bio;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _contact = TextEditingController(text: widget.initial.contact);
    _church = TextEditingController(text: widget.initial.church);
    _bio = TextEditingController(text: widget.initial.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _church.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                mq.viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.editProfile,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr.profileSub,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: tr.yourName,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contact,
                      decoration: InputDecoration(
                        labelText: tr.contact,
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _church,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: tr.church,
                        prefixIcon: const Icon(Icons.church_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bio,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: tr.bio,
                        hintText: tr.bioHint,
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.auto_awesome_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(
                            UserProfile(
                              name: _name.text.trim(),
                              contact: _contact.text.trim(),
                              church: _church.text.trim(),
                              bio: _bio.text.trim(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: Text(tr.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD SHEET
// ─────────────────────────────────────────────────────────────────────────────

class AddSheet extends StatefulWidget {
  final AppLanguage language;
  const AddSheet({super.key, required this.language});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _telegram = TextEditingController();
  final _phone = TextEditingController();
  final _testimony = TextEditingController();
  final _note = TextEditingController();
  final _customMethod = TextEditingController();
  DateTime _date = DateTime.now();
  BelieverStage _stage = BelieverStage.interested;
  EvangelismMethod _method = EvangelismMethod.fourSigns;
  LatLng? _location;
  String? _placeName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestCurrentLocation();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _telegram.dispose();
    _phone.dispose();
    _testimony.dispose();
    _note.dispose();
    _customMethod.dispose();
    super.dispose();
  }

  Future<void> _requestCurrentLocation() async {
    final tr = S(widget.language);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.locationServiceDisabled)));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.locationPermissionDenied)));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _location = LatLng(position.latitude, position.longitude);
        _placeName ??= tr.currentLocationAuto;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.locationAutoError)));
    }
  }

  String? _validateTelegram(S tr) {
    final telegram = _telegram.text.trim();
    if (telegram.isEmpty) return null;
    if (!_isValidTelegram(telegram)) return tr.telegramInvalid;
    return null;
  }

  String? _validatePhone(S tr) {
    final phone = _phone.text.trim();
    if (phone.isEmpty) return null;
    if (!_isValidPhone(phone)) return tr.phoneInvalid;
    return null;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickLocation() async {
    final result = await showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        language: widget.language,
        initial: _location,
        initialPlace: _placeName,
      ),
    );
    if (result != null) {
      setState(() {
        _location = result.latLng;
        _placeName = result.place;
      });
    }
  }

  void _clearLocation() {
    setState(() {
      _location = null;
      _placeName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                mq.viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.addSub,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: tr.name,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? tr.nameReq : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telegram,
                      decoration: InputDecoration(
                        labelText: tr.telegram,
                        hintText: tr.telegramHint,
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                      ),
                      keyboardType: TextInputType.url,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9_@./:?=&-]'),
                        ),
                      ],
                      validator: (_) => _validateTelegram(tr),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: tr.phone,
                        hintText: tr.phoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+()\-\s]'),
                        ),
                        _PhoneInputFormatter(),
                      ],
                      validator: (_) => _validatePhone(tr),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: tr.date,
                          prefixIcon: const Icon(Icons.calendar_today_rounded),
                          suffixIcon: const Icon(Icons.expand_more_rounded),
                        ),
                        child: Text(fmtDate(_date, widget.language)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BelieverStage>(
                      value: _stage,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr.stage,
                        prefixIcon: const Icon(Icons.flag_outlined),
                      ),
                      items: BelieverStage.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  _Dot(stage: s, size: 10),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(stageFull(s, widget.language)),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _stage = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<EvangelismMethod>(
                      value: _method,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr.evangelismMethod,
                        prefixIcon: const Icon(Icons.menu_book_rounded),
                      ),
                      items: EvangelismMethod.values
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(evangelismMethodLabel(method, tr)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _method = value);
                      },
                    ),
                    if (_method == EvangelismMethod.custom) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customMethod,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: tr.customMethod,
                          hintText: tr.customMethodHint,
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 28),
                            child: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        validator: (value) {
                          if (_method != EvangelismMethod.custom) return null;
                          if (value == null || value.trim().isEmpty) {
                            return tr.customMethodReq;
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _testimony,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: tr.testimony,
                        hintText: tr.testimonyHint,
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.auto_stories_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: tr.note,
                        hintText: tr.noteHint,
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.auto_stories_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LocationField(
                      tr: tr,
                      location: _location,
                      placeName: _placeName,
                      onPick: _pickLocation,
                      onClear: _clearLocation,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          Navigator.of(context).pop(
                            NewBeliever(
                              id: DateTime.now().microsecondsSinceEpoch
                                  .toString(),
                              name: _name.text.trim(),
                              telegram: _normalizeTelegramForStorage(
                                _telegram.text,
                              ),
                              phone: _normalizePhoneForStorage(_phone.text),
                              testimony: _testimony.text.trim(),
                              note: _note.text.trim(),
                              evangelismMethod: _method,
                              customEvangelismMethod: _customMethod.text.trim(),
                              createdAt: _date,
                              stage: _stage,
                              latitude: _location?.latitude,
                              longitude: _location?.longitude,
                              place: _placeName,
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: Text(tr.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION PICKER
// ─────────────────────────────────────────────────────────────────────────────

class LocationPickerSheet extends StatefulWidget {
  final AppLanguage language;
  final LatLng? initial;
  final String? initialPlace;
  const LocationPickerSheet({
    super.key,
    required this.language,
    this.initial,
    this.initialPlace,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class PickedLocation {
  final LatLng latLng;
  final String? place;
  const PickedLocation({required this.latLng, this.place});
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  static const _fallbackCenter = LatLng(55.7558, 37.6173);
  late final MapController _mapController;
  late final TextEditingController _placeCtrl;
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selected = widget.initial;
    _placeCtrl = TextEditingController(text: widget.initialPlace ?? '');
  }

  @override
  void dispose() {
    _placeCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() => _selected = point);
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final initialCenter = widget.initial ?? _fallbackCenter;

    return Container(
      height: mq.size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.pickOnMap,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr.tapToPlace,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: widget.initial != null ? 13 : 4,
                      minZoom: 2,
                      maxZoom: 18,
                      onTap: _onMapTap,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.time_to_go_app',
                        maxNativeZoom: 19,
                      ),
                      if (_selected != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selected!,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: _PinIcon(color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: Colors.white.withOpacity(0.7),
                      child: Text(
                        tr.attribution,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _placeCtrl,
                    decoration: InputDecoration(
                      labelText: tr.placeName,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(tr.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _selected == null
                              ? null
                              : () {
                                  final placeText = _placeCtrl.text.trim();
                                  Navigator.of(context).pop(
                                    PickedLocation(
                                      latLng: _selected!,
                                      place: placeText.isEmpty
                                          ? null
                                          : placeText,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(tr.done),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinIcon extends StatelessWidget {
  final Color color;
  final double size;
  const _PinIcon({required this.color, this.size = 36});
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.location_on_rounded,
          color: color,
          size: size,
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        Positioned(
          top: size * 0.22,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP PAGE
// ─────────────────────────────────────────────────────────────────────────────

class MapPage extends StatefulWidget {
  final S tr;
  final List<NewBeliever> believers;
  final VoidCallback onSettings;
  const MapPage({
    super.key,
    required this.tr,
    required this.believers,
    required this.onSettings,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _fallbackCenter = LatLng(55.7558, 37.6173);
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<NewBeliever> get _withLocation =>
      widget.believers.where((b) => b.hasLocation).toList();

  LatLng _initialCenter() {
    final list = _withLocation;
    if (list.isEmpty) return _fallbackCenter;
    return list.first.latLng!;
  }

  void _fitAll() {
    final list = _withLocation;
    if (list.isEmpty) return;
    if (list.length == 1) {
      _mapController.move(list.first.latLng!, 13);
      return;
    }
    final points = list.map((b) => b.latLng!).toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  void _showBeliever(NewBeliever b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BelieverPreviewSheet(item: b, lang: widget.tr.lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final theme = Theme.of(context);
    final list = _withLocation;

    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _PageHeader(
            title: tr.mapTitle,
            subtitle: tr.mapSub,
            onSettings: widget.onSettings,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primary.withOpacity(
                      0.12,
                    ),
                    child: Icon(
                      Icons.place_rounded,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr.noPlaces,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr.noPlacesSub,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            title: tr.mapTitle,
            subtitle: tr.mapSub,
            onSettings: widget.onSettings,
            trailingSubtitle: _Pill(
              icon: Icons.place_rounded,
              text: '${list.length} ${tr.withLocation.toLowerCase()}',
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _initialCenter(),
                      initialZoom: list.length == 1 ? 12 : 4,
                      minZoom: 2,
                      maxZoom: 18,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.time_to_go_app',
                        maxNativeZoom: 19,
                      ),
                      MarkerLayer(
                        markers: list
                            .map(
                              (b) => Marker(
                                point: b.latLng!,
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: GestureDetector(
                                  onTap: () => _showBeliever(b),
                                  child: _PinIcon(color: stageColor(b.stage)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Material(
                      color: theme.colorScheme.surface,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _fitAll,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.center_focus_strong_rounded,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: Colors.white.withOpacity(0.7),
                      child: Text(
                        tr.attribution,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BelieverStage.values
                    .map((s) => _LegendChip(stage: s, lang: tr.lang))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BelieverPreviewSheet extends StatelessWidget {
  final NewBeliever item;
  final AppLanguage lang;
  const _BelieverPreviewSheet({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: t.brightness == Brightness.dark
                ? Colors.white.withOpacity(0.07)
                : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Dot(stage: item.stage, size: 12),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: t.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _Chip(stage: item.stage, lang: lang),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: Icons.calendar_today_rounded,
                    text: fmtDate(item.createdAt, lang),
                  ),
                  if (item.place != null && item.place!.isNotEmpty)
                    _Pill(icon: Icons.location_on_rounded, text: item.place!),
                ],
              ),
              const SizedBox(height: 12),
              _Pill(
                icon: Icons.menu_book_rounded,
                text:
                    item.evangelismMethod == EvangelismMethod.custom &&
                        item.customEvangelismMethod.isNotEmpty
                    ? item.customEvangelismMethod
                    : evangelismMethodLabel(item.evangelismMethod, S(lang)),
              ),
              if (item.testimony.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.testimony,
                  style: t.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.note,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(lang == AppLanguage.ru ? 'Закрыть' : 'Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSettings;
  final Widget? trailingSubtitle;
  const _PageHeader({
    required this.title,
    this.subtitle,
    this.onSettings,
    this.trailingSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (onSettings != null) ...[
              const SizedBox(width: 8),
              Material(
                color: theme.colorScheme.primary.withOpacity(0.10),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSettings,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          if (trailingSubtitle != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                trailingSubtitle!,
              ],
            )
          else
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _FullCard extends StatelessWidget {
  final NewBeliever item;
  final AppLanguage lang;
  final VoidCallback onDelete;
  final ValueChanged<BelieverStage> onStage;
  const _FullCard({
    required this.item,
    required this.lang,
    required this.onDelete,
    required this.onStage,
  });
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: ExpansionTile(
        key: PageStorageKey('believer-${item.id}'),
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: _Dot(stage: item.stage, size: 12),
        title: Text(
          item.name,
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          stageShort(item.stage, lang),
          style: t.textTheme.bodySmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: Icons.calendar_today_rounded,
                text: fmtDate(item.createdAt, lang),
              ),
              if (item.telegram.isNotEmpty)
                _Pill(
                  icon: Icons.telegram,
                  text: item.telegram,
                  onTap: () => openTelegram(item.telegram),
                ),
              if (item.phone.isNotEmpty)
                _Pill(
                  icon: Icons.phone_rounded,
                  text: formatPhoneForDisplay(item.phone),
                  onTap: () => callPhone(item.phone),
                ),
              if (item.place != null && item.place!.isNotEmpty)
                _Pill(icon: Icons.location_on_rounded, text: item.place!)
              else if (item.hasLocation)
                _Pill(
                  icon: Icons.location_on_rounded,
                  text:
                      '${item.latitude!.toStringAsFixed(3)}, ${item.longitude!.toStringAsFixed(3)}',
                ),
              _Pill(
                icon: Icons.menu_book_rounded,
                text:
                    item.evangelismMethod == EvangelismMethod.custom &&
                        item.customEvangelismMethod.isNotEmpty
                    ? item.customEvangelismMethod
                    : evangelismMethodLabel(item.evangelismMethod, S(lang)),
              ),
            ],
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.note,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (item.testimony.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.testimony,
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<BelieverStage>(
            value: item.stage,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: lang == AppLanguage.ru ? 'Этап' : 'Stage',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            items: BelieverStage.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        _Dot(stage: s, size: 10),
                        const SizedBox(width: 10),
                        Flexible(child: Text(stageFull(s, lang))),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onStage(v);
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(lang == AppLanguage.ru ? 'Удалить' : 'Delete'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final BelieverStage stage;
  final AppLanguage lang;
  const _LegendChip({required this.stage, required this.lang});
  @override
  Widget build(BuildContext context) {
    final c = stageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(stage: stage, size: 8),
          const SizedBox(width: 6),
          Text(
            stageShort(stage, lang),
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _Pill({required this.icon, required this.text, this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: t.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final BelieverStage stage;
  final double size;
  const _Dot({required this.stage, this.size = 12});
  @override
  Widget build(BuildContext context) {
    final c = stageColor(stage);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 6)],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final BelieverStage stage;
  final AppLanguage lang;
  const _Chip({required this.stage, required this.lang});
  @override
  Widget build(BuildContext context) {
    final c = stageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        stageShort(stage, lang),
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final S tr;
  final LatLng? location;
  final String? placeName;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _LocationField({
    required this.tr,
    required this.location,
    required this.placeName,
    required this.onPick,
    required this.onClear,
  });

  String _coords(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);
    final fill = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    if (location == null) {
      return Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_location_alt_outlined,
                  color: t.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.locationOptional,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr.tapToPlace,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        color: fill,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: location!,
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.time_to_go_app',
                      maxNativeZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: location!,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: _PinIcon(
                            color: t.colorScheme.primary,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: t.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (placeName != null && placeName!.isNotEmpty)
                            ? placeName!
                            : tr.location,
                        style: t.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _coords(location!),
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr.changeLocation,
                  onPressed: onPick,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
                IconButton(
                  tooltip: tr.clearLocation,
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final S tr;
  final VoidCallback onAdd;
  const _Empty({required this.tr, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: t.colorScheme.primary.withOpacity(0.12),
              child: Icon(
                Icons.person_add_alt_1_rounded,
                size: 26,
                color: t.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr.emptyTitle,
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr.emptySub,
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(tr.add),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

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
  factory NewBeliever.fromMap(Map<String, dynamic> m) => NewBeliever(
    id: m['id'] as String,
    remoteId: (m['remoteId'] as num?)?.toInt(),
    name: m['name'] as String? ?? '',
    telegram: m['telegram'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    testimony: m['testimony'] as String? ?? '',
    note: m['note'] as String? ?? '',
    evangelismMethod: EvangelismMethod.values.firstWhere(
      (e) => e.name == m['evangelismMethod'],
      orElse: () => EvangelismMethod.fourSigns,
    ),
    customEvangelismMethod: m['customEvangelismMethod'] as String? ?? '',
    createdAt:
        DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
    stage: BelieverStage.values.firstWhere(
      (e) => e.name == m['stage'],
      orElse: () => BelieverStage.interested,
    ),
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    place: m['place'] as String?,
  );
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

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    name: m['name'] as String? ?? '',
    contact: m['contact'] as String? ?? '',
    church: m['church'] as String? ?? '',
    bio: m['bio'] as String? ?? '',
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
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return '?';
    final list = parts.toList();
    final first = list.first[0];
    final last = list.length > 1 ? list.last[0] : '';
    return (first + last).toUpperCase();
  }

  factory BackendUser.fromMap(Map<String, dynamic> map) => BackendUser(
    id: (map['id'] as num?)?.toInt() ?? 0,
    name: (map['name'] as String? ?? '').trim(),
    email: (map['email'] as String? ?? '').trim(),
    avatarUrl: (map['avatar_url'] as String? ?? '').trim(),
    about: (map['about'] as String? ?? '').trim(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color stageColor(BelieverStage s) => switch (s) {
  BelieverStage.interested => const Color(0xFF4D90FE),
  BelieverStage.receivedJesus => const Color(0xFF9B6DFF),
  BelieverStage.joinedCommunity => const Color(0xFF00A896),
  BelieverStage.baptised => const Color(0xFFF4A261),
  BelieverStage.evangelist => const Color(0xFF43AA5C),
};

String stageFull(BelieverStage s, AppLanguage l) => switch (s) {
  BelieverStage.interested =>
    l == AppLanguage.ru ? 'Интересуется верой' : 'Interested in faith',
  BelieverStage.receivedJesus =>
    l == AppLanguage.ru ? 'Принял Иисуса' : 'Received Jesus',
  BelieverStage.joinedCommunity =>
    l == AppLanguage.ru ? 'Пришёл в церковь / группу' : 'Joined community',
  BelieverStage.baptised => l == AppLanguage.ru ? 'Крестился' : 'Got baptised',
  BelieverStage.evangelist =>
    l == AppLanguage.ru ? 'Проповедует Евангелие' : 'Preaches the gospel',
};

String stageShort(BelieverStage s, AppLanguage l) => switch (s) {
  BelieverStage.interested => l == AppLanguage.ru ? 'Интерес' : 'Interested',
  BelieverStage.receivedJesus => l == AppLanguage.ru ? 'Принял' : 'Received',
  BelieverStage.joinedCommunity => l == AppLanguage.ru ? 'Группа' : 'Community',
  BelieverStage.baptised => l == AppLanguage.ru ? 'Крещение' : 'Baptised',
  BelieverStage.evangelist => l == AppLanguage.ru ? 'Служит' : 'Serving',
};

EvangelismMethod methodFromBackendName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return EvangelismMethod.custom;
  if ((normalized.contains('4') && normalized.contains('знак')) ||
      normalized.contains('four signs')) {
    return EvangelismMethod.fourSigns;
  }
  if (normalized.contains('двер') || normalized.contains('door')) {
    return EvangelismMethod.jesusAtDoor;
  }
  return EvangelismMethod.custom;
}

String evangelismMethodLabel(EvangelismMethod method, S tr) => switch (method) {
  EvangelismMethod.fourSigns => tr.methodFourSignsTab,
  EvangelismMethod.jesusAtDoor => tr.methodJesusDoorTab,
  EvangelismMethod.custom => tr.methodCustom,
};

String _telegramUrl(String value) {
  final handle = _extractTelegramHandle(value);
  if (handle == null) return '';
  return 'https://t.me/$handle';
}

Future<void> openTelegram(String value) async {
  final uri = Uri.tryParse(_telegramUrl(value));
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> callPhone(String value) async {
  final cleaned = _normalizePhoneForStorage(value);
  if (cleaned.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: cleaned);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String? _extractTelegramHandle(String value) {
  var raw = value.trim();
  if (raw.isEmpty) return null;

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (host == 't.me' || host == 'telegram.me') {
      raw = uri!.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    }
  } else if (raw.startsWith('t.me/') || raw.startsWith('telegram.me/')) {
    final parts = raw.split('/');
    raw = parts.isNotEmpty ? parts.last : '';
  }

  raw = raw.startsWith('@') ? raw.substring(1) : raw;
  raw = raw.split('?').first.split('#').first.trim();
  if (raw.isEmpty) return null;
  return raw;
}

bool _isValidTelegram(String value) {
  final handle = _extractTelegramHandle(value);
  if (handle == null) return false;
  return RegExp(r'^[a-zA-Z0-9_]{5,32}$').hasMatch(handle);
}

String _normalizeTelegramForStorage(String value) {
  final handle = _extractTelegramHandle(value);
  if (handle == null) return '';
  return '@$handle';
}

bool _isValidPhone(String value) {
  final digits = _phoneDigits(value);
  return digits.length >= 10 && digits.length <= 15;
}

String _phoneDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _formatPhoneForInput(String value) {
  var digits = _phoneDigits(value);
  if (digits.isEmpty) return '';
  if (digits.length > 15) digits = digits.substring(0, 15);

  final ruCandidate =
      digits.length <= 11 && (digits.startsWith('7') || digits.startsWith('8'));
  if (ruCandidate) {
    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    final rest = digits.substring(1);
    final b = StringBuffer('+7');
    if (rest.isNotEmpty) {
      b.write(' (${rest.substring(0, rest.length.clamp(0, 3))}');
    }
    if (rest.length >= 4) {
      b.write(') ${rest.substring(3, rest.length.clamp(3, 6))}');
    }
    if (rest.length >= 7) {
      b.write('-${rest.substring(6, rest.length.clamp(6, 8))}');
    }
    if (rest.length >= 9) {
      b.write('-${rest.substring(8, rest.length.clamp(8, 10))}');
    }
    return b.toString();
  }

  final b = StringBuffer('+');
  for (var i = 0; i < digits.length; i++) {
    b.write(digits[i]);
    if (i == 2 || i == 5 || i == 8 || i == 11) {
      if (i != digits.length - 1) b.write(' ');
    }
  }
  return b.toString().trim();
}

String _normalizePhoneForStorage(String value) {
  var digits = _phoneDigits(value);
  if (digits.isEmpty) return '';
  if (digits.length == 11 && digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }
  if (digits.length > 15) digits = digits.substring(0, 15);
  return '+$digits';
}

String formatPhoneForDisplay(String value) => _formatPhoneForInput(value);

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatPhoneForInput(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String fmtDate(DateTime d, AppLanguage l) {
  try {
    return DateFormat(
      l == AppLanguage.ru ? 'dd.MM.yyyy' : 'MMM d, yyyy',
      l == AppLanguage.ru ? 'ru_RU' : 'en_US',
    ).format(d);
  } catch (_) {
    return DateFormat('dd.MM.yyyy').format(d);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STRINGS
// ─────────────────────────────────────────────────────────────────────────────

class S {
  final AppLanguage lang;
  S(this.lang);
  bool get _ru => lang == AppLanguage.ru;

  String get appTitle => _ru ? "Время идти" : "Time To Go";
  String get dashSub => _ru
      ? 'Учёт новых верующих и этапов духовного роста'
      : 'Track new believers and their growth';
  String get homeWitnessSub => _ru
      ? 'Свидетельство дня и ключевые цифры'
      : 'Testimony of the day and key numbers';
  String get testimonyOfDay =>
      _ru ? 'Свидетельство дня' : 'Testimony of the day';
  String get noTestimonyToday =>
      _ru ? 'Пока нет свидетельства дня.' : 'No testimony of the day yet.';
  String get heardGospelCountLabel => _ru
      ? 'Всего человек услышало Евангелие'
      : 'Total people heard the Gospel';
  String get acceptedJesusCountLabel =>
      _ru ? 'Человек приняло Иисуса' : 'People accepted Jesus';
  String get heroTitle => _ru
      ? 'Время идти\nи благовествовать'
      : 'Time to go\nand preach the gospel';
  String get heroSub => _ru
      ? 'Ведите учёт людей, отслеживайте этапы роста и готовьтесь к труду.'
      : 'Track people, follow growth stages, prepare for ministry.';
  String get total => _ru ? 'Всего' : 'Total';
  String get inProgress => _ru ? 'В пути' : 'In progress';
  String get serving => _ru ? 'Служат' : 'Serving';
  String get sections => _ru ? 'Разделы' : 'Sections';
  String get recent => _ru ? 'Недавние' : 'Recent';
  String get believers => _ru ? 'Новые верующие' : 'New believers';
  String get savedPeople => _ru ? 'Спасенные' : 'Saved';
  String get believersSub => _ru
      ? 'Добавляйте людей и переводите по этапам'
      : 'Add people and move through stages';
  String get list => _ru ? 'Список' : 'List';
  String get methods => _ru ? 'Методы' : 'Methods';
  String get methodsSub => _ru
      ? 'Четыре знака и «Иисус у двери»'
      : 'Four signs and “Jesus at the door”';
  String get methodsPageTitle =>
      _ru ? 'Методы евангелизации' : 'Evangelism methods';
  String get methodsPageSub => _ru
      ? 'Переключайтесь между способами и используйте схемы в беседе.'
      : 'Switch between methods and use the visuals in conversation.';
  String get authSub => _ru
      ? 'Войдите, чтобы синхронизировать данные между устройствами.'
      : 'Sign in to sync your data across devices.';
  String get methodFourSignsTab => _ru ? '4 знака' : 'Four signs';
  String get methodJesusDoorTab => _ru ? 'Иисус у двери' : 'Jesus at the door';
  String get methodCustom => _ru ? 'Свой метод' : 'My method';
  String get imageMissing =>
      _ru ? 'Не удалось загрузить изображение' : 'Could not load image';
  String get map => _ru ? 'Карта' : 'Map';
  String get settings => _ru ? 'Настройки' : 'Settings';
  String get settingsSub => _ru ? 'Тема и язык' : 'Theme and language';
  String get account => _ru ? 'Аккаунт' : 'Account';
  String get home => _ru ? 'Главная' : 'Home';
  String get add => _ru ? 'Добавить' : 'Add';
  String get saved => _ru ? 'Сохранено локально' : 'Saved locally';
  String get testimonies => _ru ? 'Свидетельства' : 'Testimonies';
  String get trackSub => _ru ? 'Учёт и статусы' : 'Tracking & status';
  String get soon => _ru ? 'Скоро' : 'Coming soon';
  String get mapHint => _ru
      ? 'Карта точек служения появится в следующем обновлении.'
      : 'Ministry map is coming in a future update.';
  String get themeLabel => _ru ? 'Тема' : 'Theme';
  String get sys => _ru ? 'Авто' : 'Auto';
  String get light => _ru ? 'Светло' : 'Light';
  String get dark => _ru ? 'Темно' : 'Dark';
  String get langLabel => _ru ? 'Язык' : 'Language';
  String get signIn => _ru ? 'Войти' : 'Sign in';
  String get signUp => _ru ? 'Регистрация' : 'Sign up';
  String get signOut => _ru ? 'Выйти' : 'Sign out';
  String get signOutConfirmTitle =>
      _ru ? 'Выйти из аккаунта?' : 'Sign out of account?';
  String get signOutConfirmBody => _ru
      ? 'Вы уверены, что хотите выйти?'
      : 'Are you sure you want to sign out?';
  String get continueOffline =>
      _ru ? 'Продолжить без входа' : 'Continue without sign in';
  String get authEmail => _ru ? 'Email' : 'Email';
  String get authPassword => _ru ? 'Пароль' : 'Password';
  String get authInvalidEmail =>
      _ru ? 'Введите корректный email' : 'Enter a valid email';
  String get authPasswordRule => _ru
      ? 'Пароль должен быть не короче 6 символов'
      : 'Password must be at least 6 characters';
  String get authWrongCredentials =>
      _ru ? 'Неверный email или пароль' : 'Invalid email or password';
  String get authEmailExists => _ru
      ? 'Пользователь с таким email уже существует'
      : 'Email already exists';
  String get authInvalidInput =>
      _ru ? 'Проверьте корректность введенных данных' : 'Check input fields';
  String get authNetworkError =>
      _ru ? 'Не удалось подключиться к серверу' : 'Could not connect to server';
  String get authUnknownError =>
      _ru ? 'Не удалось выполнить авторизацию' : 'Authorization failed';

  String get addSub => _ru
      ? 'Данные хранятся локально на устройстве.'
      : 'Data is stored locally on your device.';
  String get name => _ru ? 'Имя' : 'Name';
  String get contact => _ru ? 'Контакт' : 'Contact';
  String get telegram => _ru ? 'Telegram' : 'Telegram';
  String get phone => _ru ? 'Телефон' : 'Phone number';
  String get telegramHint =>
      _ru ? '@username или t.me/username' : '@username or t.me/username';
  String get phoneHint => _ru ? '+7 (999) 123-45-67' : '+1 555 123 45 67';
  String get contactReqEither => _ru
      ? 'Укажите Telegram или номер телефона'
      : 'Enter Telegram or phone number';
  String get telegramInvalid => _ru
      ? 'Неверный Telegram. Пример: @username'
      : 'Invalid Telegram. Example: @username';
  String get phoneInvalid =>
      _ru ? 'Неверный номер телефона' : 'Invalid phone number';
  String get date => _ru ? 'Дата' : 'Date';
  String get stage => _ru ? 'Этап' : 'Stage';
  String get evangelismMethod =>
      _ru ? 'Метод евангелизации' : 'Evangelism method';
  String get customMethod => _ru ? 'Свой метод' : 'Custom method';
  String get customMethodHint => _ru
      ? 'Опишите ваш метод евангелизации'
      : 'Describe your evangelism method';
  String get customMethodReq =>
      _ru ? 'Введите описание своего метода' : 'Describe your custom method';
  String get testimony => _ru ? 'Свидетельство' : 'Testimony';
  String get testimonyHint => _ru
      ? 'Что произошло в этой встрече?'
      : 'What happened during this meeting?';
  String get note => _ru ? 'Заметка' : 'Note';
  String get noteHint =>
      _ru ? 'Краткая заметка о человеке' : 'Short note about this person';
  String get save => _ru ? 'Сохранить' : 'Save';
  String get nameReq => _ru ? 'Введите имя' : 'Enter a name';
  String get emptyTitle => _ru ? 'Пока никого нет' : 'No believers yet';
  String get emptySub => _ru
      ? 'Добавь первого человека, чтобы начать вести учёт.'
      : 'Add the first person to start tracking.';

  String get believersNav => _ru ? 'Верующие' : 'Believers';
  String get homeNav => _ru ? 'Главная' : 'Home';
  String get methodsNav => _ru ? 'Методы' : 'Methods';
  String get mapNav => _ru ? 'Карта' : 'Map';
  String get settingsNav => _ru ? 'Настройки' : 'Settings';
  String get profileNav => _ru ? 'Профиль' : 'Profile';

  String get profile => _ru ? 'Профиль' : 'Profile';
  String get profileSub =>
      _ru ? 'Информация о вас и вашем служении' : 'About you and your ministry';
  String get profileNeedAuth => _ru
      ? 'Войдите, чтобы открыть профиль аккаунта'
      : 'Sign in to open account profile';
  String get profileNeedAuthSub => _ru
      ? 'После входа здесь будет ваш профиль из бэкенда.'
      : 'After sign in, your backend account profile will appear here.';
  String get editAccountProfile =>
      _ru ? 'Редактировать аккаунт' : 'Edit account profile';
  String get changeAvatar => _ru ? 'Изменить фото' : 'Change photo';
  String get editProfile => _ru ? 'Редактировать' : 'Edit profile';
  String get fillProfile => _ru ? 'Заполнить профиль' : 'Fill profile';
  String get yourName => _ru ? 'Ваше имя' : 'Your name';
  String get church => _ru ? 'Церковь / община' : 'Church / community';
  String get bio => _ru ? 'О служении' : 'About ministry';
  String get bioHint => _ru
      ? 'Где вы служите, к чему призваны?'
      : 'Where do you serve, what are you called to?';
  String get about => _ru ? 'О себе' : 'About';
  String get serverAccount => _ru ? 'Профиль аккаунта' : 'Account profile';
  String get serverAccountUnavailable => _ru
      ? 'Не удалось загрузить профиль аккаунта с сервера.'
      : 'Could not load account profile from server.';
  String get accountInfo => _ru ? 'Данные аккаунта' : 'Account info';
  String get noProfile => _ru ? 'Профиль не заполнен' : 'Profile is empty';
  String get noProfileSub => _ru
      ? 'Добавьте информацию о себе и вашем служении.'
      : 'Add information about yourself and your ministry.';
  String get noName => _ru ? 'Без имени' : 'No name';

  String get location => _ru ? 'Место' : 'Location';
  String get locationOptional =>
      _ru ? 'Место (необязательно)' : 'Location (optional)';
  String get currentLocationAuto =>
      _ru ? 'Текущее местоположение' : 'Current location';
  String get locationServiceDisabled => _ru
      ? 'Включите геолокацию на устройстве'
      : 'Enable location services on your device';
  String get locationPermissionDenied => _ru
      ? 'Разрешите доступ к геолокации, чтобы автоматически отметить свидетельство'
      : 'Allow location access to auto-mark the testimony';
  String get locationAutoError => _ru
      ? 'Не удалось определить текущую геолокацию'
      : 'Could not determine current location';
  String get pickOnMap => _ru ? 'Отметить на карте' : 'Pick on map';
  String get changeLocation => _ru ? 'Изменить место' : 'Change location';
  String get clearLocation => _ru ? 'Убрать место' : 'Clear location';
  String get placeName =>
      _ru ? 'Название места (необязательно)' : 'Place name (optional)';
  String get tapToPlace => _ru
      ? 'Нажмите на карту, чтобы поставить метку'
      : 'Tap the map to place a marker';
  String get done => _ru ? 'Готово' : 'Done';
  String get cancel => _ru ? 'Отмена' : 'Cancel';
  String get mapTitle => _ru ? 'Карта свидетельств' : 'Testimony map';
  String get mapSub =>
      _ru ? 'Где Бог встретил этих людей' : 'Places where God met these people';
  String get noPlaces =>
      _ru ? 'Пока нет отмеченных мест' : 'No places marked yet';
  String get noPlacesSub => _ru
      ? 'Отметьте человека на карте при добавлении или редактировании.'
      : 'Mark a person on the map when adding or editing.';
  String get withLocation => _ru ? 'С местом' : 'With location';
  String get viewProfile => _ru ? 'Открыть карточку' : 'Open card';
  String get attribution => '© OpenStreetMap contributors';
}
