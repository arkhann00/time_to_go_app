part of '../main.dart';

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
  final PushNotificationService pushNotifications;
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
    required this.pushNotifications,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _key = 'believers_v2';
  final List<NewBeliever> _list = [];
  final List<NewBeliever> _mapList = [];
  final Map<EvangelismMethod, int> _defaultMethodIds = {};
  final Map<String, int> _customMethodIds = {};
  BackendUser? _backendUser;
  String? _cachedAvatarPath;
  final UserProfileCache _profileCache = UserProfileCache();
  List<LatestTestimony> _latestTestimonies = [];
  bool _dashboardLoading = true;
  bool _loading = true;
  int _tab = 0;

  SummaryStats? _generalSummary;
  SummaryStats? _personalSummary;
  bool _summaryLoading = true;
  OutreachStatEntry? _myStats;
  bool _myStatsLoading = true;

  BackendApi get _backendApi => widget.backendApi;

  @override
  void initState() {
    super.initState();
    widget.pushNotifications.setOpenBelieversCallback(() {
      if (mounted) setState(() => _tab = 1);
    });
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
    String? cachedAvatarPath;
    final localItems = raw
        .map((e) => NewBeliever.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    var items = [...localItems]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var mapItems = [...items];

    if (_backendApi.hasAuth) {
      final cachedJson = await _profileCache.loadUserJson();
      if (cachedJson != null) {
        try {
          backendUser = BackendUser.fromMap(
            jsonDecode(cachedJson) as Map<String, dynamic>,
          );
          cachedAvatarPath = await _profileCache.loadAvatarLocalPath();
        } catch (_) {}
      }

      try {
        if (widget.migrateLocalOnAuth) {
          await _migrateLocalBelieversToServer(localItems);
        }
        backendUser = BackendUser.fromMap(await _backendApi.me());
        await _profileCache.saveUserJson(jsonEncode(backendUser.toMap()));
        cachedAvatarPath = await _profileCache.syncAvatar(
          avatarUrl: backendUser.avatarUrl,
          api: _backendApi,
          resolveUrl: _resolveAvatarUrl,
        );
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
        // Keep cached profile and local data when backend is unavailable.
      } finally {
        if (widget.migrateLocalOnAuth) {
          widget.onMigrationHandled();
        }
      }
    }

    // Map should show absolutely all believers (and their testimonies),
    // not only the ones owned by the current user.
    try {
      final remoteAll = await _backendApi.getAllBelievers();
      mapItems = remoteAll.map(_fromBackendBeliever).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      // Fallback: keep whatever we already have (local/my believers).
    }

    final testimonies = await _loadTestimonies();

    // Load summary stats
    SummaryStats? generalSummary;
    SummaryStats? personalSummary;
    OutreachStatEntry? myStats;
    try {
      generalSummary = SummaryStats.fromMap(
        await _backendApi.getOutreachStatisticsSummary(type: 'general'),
      );
    } catch (_) {}

    if (_backendApi.hasAuth) {
      try {
        personalSummary = SummaryStats.fromMap(
          await _backendApi.getOutreachStatisticsSummary(type: 'personal'),
        );
      } catch (_) {}
      try {
        myStats = OutreachStatEntry.fromMap(
          await _backendApi.getMyOutreachStatistics(),
        );
      } catch (_) {}
    }

    setState(() {
      _list
        ..clear()
        ..addAll(items);
      _mapList
        ..clear()
        ..addAll(mapItems);
      _backendUser = backendUser;
      _cachedAvatarPath = cachedAvatarPath;
      _latestTestimonies = testimonies;
      _dashboardLoading = false;
      _loading = false;
      _generalSummary = generalSummary;
      _personalSummary = personalSummary;
      _summaryLoading = false;
      _myStats = myStats;
      _myStatsLoading = false;
    });
  }

  Future<void> _persistProfileCache(
    BackendUser user, {
    String? avatarFilePath,
  }) async {
    await _profileCache.saveUserJson(jsonEncode(user.toMap()));
    final avatarPath = avatarFilePath != null
        ? await _profileCache.saveAvatarFromLocalFile(avatarFilePath)
        : await _profileCache.syncAvatar(
            avatarUrl: user.avatarUrl,
            api: _backendApi,
            resolveUrl: _resolveAvatarUrl,
          );
    if (mounted) {
      setState(() => _cachedAvatarPath = avatarPath);
    }
  }

  Future<List<LatestTestimony>> _loadTestimonies() async {
    var testimonies = <LatestTestimony>[];

    try {
      final all = await _backendApi.getTestimonies();
      testimonies = all
          .map(_latestTestimonyFromRaw)
          .whereType<LatestTestimony>()
          .toList();
    } catch (_) {}

    if (testimonies.isEmpty) {
      try {
        final day = await _backendApi.getTestimonyOfDay();
        final t = _latestTestimonyFromRaw(day);
        if (t != null) testimonies = [t];
      } on BackendApiException catch (e) {
        if (e.statusCode == 404) testimonies = [];
      } catch (_) {}
    }

    return testimonies;
  }

  Future<void> _refreshSummary() async {
    SummaryStats? general;
    SummaryStats? personal;
    try {
      general = SummaryStats.fromMap(
        await _backendApi.getOutreachStatisticsSummary(type: 'general'),
      );
    } catch (_) {}
    if (_backendApi.hasAuth) {
      try {
        personal = SummaryStats.fromMap(
          await _backendApi.getOutreachStatisticsSummary(type: 'personal'),
        );
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      if (general != null) _generalSummary = general;
      if (personal != null) _personalSummary = personal;
    });
  }

  LatestTestimony? _latestTestimonyFromRaw(Map<String, dynamic> raw) {
    final text = (raw['testimony'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    final ownerMap = raw['owner'] as Map<String, dynamic>?;
    final addedByName = (ownerMap?['name'] as String? ?? '').trim();
    final addedByAvatarUrl = _resolveAvatarUrl(
      ownerMap?['avatar_url'] as String?,
    );
    final believerName = (raw['believer_name'] as String? ?? '').trim();
    final metAt = (raw['met_at'] as String? ?? '').trim();
    final createdAt = DateTime.tryParse(metAt) ?? DateTime.now();
    return LatestTestimony(
      text: text,
      author: believerName.isEmpty ? null : believerName,
      addedByName: addedByName.isEmpty ? null : addedByName,
      addedByAvatarUrl: addedByAvatarUrl,
      createdAt: createdAt,
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
        backendApi: _backendApi,
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
      final updated = BackendUser.fromMap(map);
      setState(() => _backendUser = updated);
      await _persistProfileCache(updated, avatarFilePath: result.avatarPath);
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
    final testimonies = await _loadTestimonies();
    if (!mounted) return;
    setState(() => _latestTestimonies = testimonies);
    await _refreshSummary();
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
    await _refreshSummary();
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
    await _refreshSummary();
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

  Future<void> _addOutreachStats({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
    required int fathersLettersDistributed,
    required int healingsDeliverances,
    String? testimony,
  }) async {
    final result = await _backendApi.addOutreachStatistics(
      gospelsTold: gospelsTold,
      salvationPrayedUnreachable: salvationPrayedUnreachable,
      scripturesDistributed: scripturesDistributed,
      fathersLettersDistributed: fathersLettersDistributed,
      healingsDeliverances: healingsDeliverances,
      testimony: testimony,
    );
    if (mounted) {
      setState(() => _myStats = OutreachStatEntry.fromMap(result));
    }
    await _refreshSummary();
  }

  Future<void> _editOutreachStats({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
    required int fathersLettersDistributed,
    required int healingsDeliverances,
  }) async {
    final result = await _backendApi.patchOutreachStatisticsMe(
      gospelsTold: gospelsTold,
      salvationPrayedUnreachable: salvationPrayedUnreachable,
      scripturesDistributed: scripturesDistributed,
      fathersLettersDistributed: fathersLettersDistributed,
      healingsDeliverances: healingsDeliverances,
    );
    if (mounted) {
      setState(() => _myStats = OutreachStatEntry.fromMap(result));
    }
    await _refreshSummary();
  }

  Future<void> _resetOutreachStats() async {
    final result = await _backendApi.resetOutreachStatistics();
    if (mounted) {
      setState(() => _myStats = OutreachStatEntry.fromMap(result));
    }
    await _refreshSummary();
  }

  Future<void> _deleteAccount() async {
    await _backendApi.deleteMyAccount();
    await widget.onLogout();
  }

  Future<void> _deleteOutreachTestimony(int testimonyId) async {
    final result = await _backendApi.patchOutreachStatisticsMe(
      deleteTestimonyId: testimonyId,
    );
    if (mounted) setState(() => _myStats = OutreachStatEntry.fromMap(result));
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);

    final pages = [
      DashboardPage(
        tr: tr,
        latestTestimonies: _latestTestimonies,
        loading: _dashboardLoading,
        summaryLoading: _summaryLoading,
        generalSummary: _generalSummary,
        personalSummary: _personalSummary,
        isAuthenticated: widget.isAuthenticated,
        onSettings: _openSettings,
        onRefresh: _load,
        onAddOutreachStats: widget.isAuthenticated
            ? ({
                required int gospelsTold,
                required int salvationPrayedUnreachable,
                required int scripturesDistributed,
                required int fathersLettersDistributed,
                required int healingsDeliverances,
                String? testimony,
              }) => _addOutreachStats(
                gospelsTold: gospelsTold,
                salvationPrayedUnreachable: salvationPrayedUnreachable,
                scripturesDistributed: scripturesDistributed,
                fathersLettersDistributed: fathersLettersDistributed,
                healingsDeliverances: healingsDeliverances,
                testimony: testimony,
              )
            : null,
      ),

      BelieversPage(
        tr: tr,
        believers: _list,
        loading: _loading,
        onAdd: _add,
        onDelete: _delete,
        onStage: _updateStage,
        onSettings: _openSettings,
        onRefresh: _load,
      ),
      EvangelismMethodsPage(tr: tr, onSettings: _openSettings),
      MapPage(tr: tr, believers: _mapList, onSettings: _openSettings),
      ProfilePage(
        tr: tr,
        backendUser: _backendUser,
        backendAvatarUrl: _resolveAvatarUrl(_backendUser?.avatarUrl),
        cachedAvatarPath: _cachedAvatarPath,
        isAuthenticated: widget.isAuthenticated,
        believers: _list,
        myStats: _myStats,
        myStatsLoading: _myStatsLoading,
        onOpenAuth: widget.onOpenAuth,
        onEditAccount: _editAccountProfile,
        onAddOutreachStats:
            ({
              required int gospelsTold,
              required int salvationPrayedUnreachable,
              required int scripturesDistributed,
              required int fathersLettersDistributed,
              required int healingsDeliverances,
              String? testimony,
            }) => _addOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
              fathersLettersDistributed: fathersLettersDistributed,
              healingsDeliverances: healingsDeliverances,
              testimony: testimony,
            ),
        onEditOutreachStats:
            ({
              required int gospelsTold,
              required int salvationPrayedUnreachable,
              required int scripturesDistributed,
              required int fathersLettersDistributed,
              required int healingsDeliverances,
            }) => _editOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
              fathersLettersDistributed: fathersLettersDistributed,
              healingsDeliverances: healingsDeliverances,
            ),
        onResetOutreachStats: _resetOutreachStats,
        onDeleteTestimony: widget.isAuthenticated
            ? _deleteOutreachTestimony
            : null,
        onLogout: widget.onLogout,
        onDeleteAccount: widget.isAuthenticated ? _deleteAccount : null,
        onSettings: _openSettings,
        onRefresh: _load,
      ),
    ];

    if (_isApple) {
      final theme = Theme.of(context);
      final tabItems = [
        _AppleTabItem(
          icon: CupertinoIcons.square_grid_2x2,
          activeIcon: CupertinoIcons.square_grid_2x2_fill,
          label: tr.homeNav,
        ),
        _AppleTabItem(
          icon: CupertinoIcons.person_2,
          activeIcon: CupertinoIcons.person_2_fill,
          label: tr.believersNav,
        ),
        _AppleTabItem(
          icon: CupertinoIcons.book,
          activeIcon: CupertinoIcons.book_fill,
          label: tr.methodsNav,
        ),
        _AppleTabItem(
          icon: CupertinoIcons.map,
          activeIcon: CupertinoIcons.map_fill,
          label: tr.mapNav,
        ),
        _AppleTabItem(
          icon: CupertinoIcons.person_circle,
          activeIcon: CupertinoIcons.person_circle_fill,
          label: tr.profileNav,
        ),
      ];
      return Scaffold(
        backgroundColor: _iosBackground(context),
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _tab, children: pages),
        ),
        bottomNavigationBar: _AppleGlassTabBar(
          items: tabItems,
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          tint: theme.colorScheme.primary,
        ),
        floatingActionButton: _tab == 1
            ? Padding(
                padding: const EdgeInsets.only(bottom: 76),
                child: FloatingActionButton(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 6,
                  onPressed: _add,
                  child: const Icon(CupertinoIcons.add, size: 26),
                ),
              )
            : null,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
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
