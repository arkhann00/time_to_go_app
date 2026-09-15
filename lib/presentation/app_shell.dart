part of '../main.dart';

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
    defaultValue: 'https://api.time.to.go.xn--80a6ad.space',
  );
  static const _apiAccessToken = String.fromEnvironment('API_ACCESS_TOKEN');

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final BackendApi _backendApi;
  late final PushNotificationService _pushNotifications;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppLanguage _language = AppLanguage.ru;
  String? _accessToken;
  bool _continueOffline = true;
  bool _migrateLocalOnNextAuth = false;
  bool _ready = false;
  bool _regionAlertShown = false;

  @override
  void initState() {
    super.initState();
    _backendApi = BackendApi(baseUrl: _apiBaseUrl);
    _pushNotifications = PushNotificationService();
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
    if (_accessToken != null)
      unawaited(_pushNotifications.activate(_backendApi));
    if (!mounted) return;
    setState(() => _ready = true);
    unawaited(_checkRegionAndMaybeWarn());
  }

  Future<void> _checkRegionAndMaybeWarn() async {
    RegionCheckResponse response;
    try {
      response = await _backendApi.checkRegion();
    } catch (_) {
      return;
    }

    final warningMessage = response.warningMessage?.trim();
    if (!mounted ||
        !response.shouldShowWarning ||
        warningMessage == null ||
        warningMessage.isEmpty) {
      return;
    }
    _scheduleRegionAlert(warningMessage);
  }

  void _scheduleRegionAlert(String warningMessage) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _regionAlertShown) return;
      final alertContext = _navigatorKey.currentContext;
      if (alertContext == null) {
        _scheduleRegionAlert(warningMessage);
        return;
      }

      _regionAlertShown = true;
      showDialog<void>(
        context: alertContext,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        builder: (context) => _RegionAccessAlert(
          tr: S(_language),
          warningMessage: warningMessage,
        ),
      );
    });
  }

  Future<void> _onAuthSuccess(String token, bool migrateLocal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _backendApi.setAccessToken(token);
    await _pushNotifications.activate(_backendApi);
    setState(() {
      _accessToken = token;
      _continueOffline = false;
      _migrateLocalOnNextAuth = migrateLocal;
    });
  }

  Future<void> _logout() async {
    await _pushNotifications.deactivate(_backendApi);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await UserProfileCache().clear();
    _backendApi.setAccessToken(null);
    setState(() {
      _accessToken = null;
      _continueOffline = true;
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
        home: Scaffold(
          body: Center(
            child: _isApple
                ? const CupertinoActivityIndicator(radius: 14)
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
              pushNotifications: _pushNotifications,
            ),
    );
  }
}

class _RegionAccessAlert extends StatelessWidget {
  final S tr;
  final String warningMessage;

  const _RegionAccessAlert({required this.tr, required this.warningMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      elevation: 8,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colors.primary.withValues(alpha: 0.42),
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.vpn_lock_rounded,
                        size: 30,
                        color: colors.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: tr.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  tr.regionAlertTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  warningMessage,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
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

class _MiniStatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _MiniStatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _iosSecondaryLabel(context),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────────────────────────────
