part of '../main.dart';

class ProfilePage extends StatelessWidget {
  final S tr;
  final BackendUser? backendUser;
  final String? backendAvatarUrl;
  final String? cachedAvatarPath;
  final bool isAuthenticated;
  final List<NewBeliever> believers;
  final VoidCallback onOpenAuth;
  final Future<void> Function() onEditAccount;
  final Future<void> Function() onLogout;
  final Future<void> Function()? onDeleteAccount;
  final VoidCallback onSettings;
  final OutreachStatEntry? myStats;
  final bool myStatsLoading;
  final Future<void> Function({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
    required int fathersLettersDistributed,
    required int healingsDeliverances,
    String? testimony,
  })
  onAddOutreachStats;
  final Future<void> Function({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
    required int fathersLettersDistributed,
    required int healingsDeliverances,
  })
  onEditOutreachStats;
  final Future<void> Function() onResetOutreachStats;
  final Future<void> Function(int id)? onDeleteTestimony;
  final Future<void> Function() onRefresh;

  const ProfilePage({
    super.key,
    required this.tr,
    required this.backendUser,
    required this.backendAvatarUrl,
    required this.cachedAvatarPath,
    required this.isAuthenticated,
    required this.believers,
    required this.onOpenAuth,
    required this.onEditAccount,
    required this.onLogout,
    this.onDeleteAccount,
    required this.onSettings,
    required this.myStats,
    required this.myStatsLoading,
    required this.onAddOutreachStats,
    required this.onEditOutreachStats,
    required this.onResetOutreachStats,
    this.onDeleteTestimony,
    required this.onRefresh,
  });

  Future<void> _confirmLogout(BuildContext context) async {
    bool? shouldLogout;
    if (_isApple) {
      shouldLogout = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(tr.signOutConfirmTitle),
          content: Text(tr.signOutConfirmBody),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr.signOut),
            ),
          ],
        ),
      );
    } else {
      shouldLogout = await showDialog<bool>(
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
    }
    if (shouldLogout == true) await onLogout();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final del = onDeleteAccount;
    if (del == null) return;
    bool? confirmed;
    if (_isApple) {
      confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(tr.deleteAccountTitle),
          content: Text(tr.deleteAccountBody),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr.deleteAccountConfirm),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error,
            size: 32,
          ),
          title: Text(tr.deleteAccountTitle),
          content: Text(tr.deleteAccountBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr.deleteAccountConfirm),
            ),
          ],
        ),
      );
    }
    if (confirmed == true) await del();
  }

  void _openAddOutreachStatsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OutreachStatsSheet(
        tr: tr,
        existing: null,
        onSave:
            ({
              required int gospelsTold,
              required int salvationPrayedUnreachable,
              required int scripturesDistributed,
              required int fathersLettersDistributed,
              required int healingsDeliverances,
              String? testimony,
            }) => onAddOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
              fathersLettersDistributed: fathersLettersDistributed,
              healingsDeliverances: healingsDeliverances,
              testimony: testimony,
            ),
      ),
    );
  }

  void _openEditOutreachStatsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OutreachStatsSheet(
        tr: tr,
        existing: myStats,
        onSave:
            ({
              required int gospelsTold,
              required int salvationPrayedUnreachable,
              required int scripturesDistributed,
              required int fathersLettersDistributed,
              required int healingsDeliverances,
              String? testimony,
            }) => onEditOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
              fathersLettersDistributed: fathersLettersDistributed,
              healingsDeliverances: healingsDeliverances,
            ),
      ),
    );
  }

  void _openAchievementsSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AchievementsPage(
          tr: tr,
          believers: believers,
          stats: myStats,
          statsLoading: myStatsLoading,
        ),
      ),
    );
  }

  Future<void> _confirmResetStats(BuildContext context) async {
    bool? confirmed;
    if (_isApple) {
      confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: Text(tr.resetStatsTitle),
          content: Text(tr.resetStatsBody),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr.resetStats),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr.resetStatsTitle),
          content: Text(tr.resetStatsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr.resetStats),
            ),
          ],
        ),
      );
    }
    if (confirmed == true) await onResetOutreachStats();
  }

  @override
  Widget build(BuildContext context) {
    if (_isApple) return _buildApple(context);
    return _buildMaterial(context);
  }

  Widget _buildApple(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final children = <Widget>[
      _AppleLargeTitle(title: tr.profile, onSettings: onSettings),
    ];

    if (!isAuthenticated) {
      children.add(
        _AppleProfileEmpty(
          icon: CupertinoIcons.person_crop_circle_badge_plus,
          iconColor: primary,
          title: tr.profileNeedAuth,
          subtitle: tr.profileNeedAuthSub,
          actionLabel: tr.signIn,
          onAction: onOpenAuth,
        ),
      );
    } else if (backendUser == null) {
      children.add(
        _AppleProfileEmpty(
          icon: CupertinoIcons.cloud_download,
          iconColor: CupertinoColors.destructiveRed.resolveFrom(context),
          title: tr.serverAccountUnavailable,
          subtitle: null,
          actionLabel: tr.signOut,
          destructive: true,
          onAction: () => _confirmLogout(context),
        ),
      );
    } else {
      final total = believers.length;
      final savedCount = believers
          .where((b) => b.stage != BelieverStage.interested)
          .length;

      // Hero contact card with gradient bg + floating avatar
      children.add(
        _AppleProfileHero(
          user: backendUser!,
          avatarUrl: backendAvatarUrl,
          avatarLocalPath: cachedAvatarPath,
          tint: primary,
          onEdit: () async {
            await onEditAccount();
          },
          editLabel: tr.editProfile,
        ),
      );
      children.add(const SizedBox(height: 18));

      // Stat cards row (Apple Health style)
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _AppleStatCard(
                  icon: CupertinoIcons.person_3_fill,
                  tint: const Color(0xFF007AFF),
                  value: '$total',
                  label: tr.total,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AppleStatCard(
                  icon: CupertinoIcons.sparkles,
                  tint: const Color(0xFFFF9500),
                  value: '$savedCount',
                  label: tr.savedPeople,
                ),
              ),
            ],
          ),
        ),
      );

      if (backendUser!.about.isNotEmpty) {
        children.add(const SizedBox(height: 22));
        children.add(
          _AppleSection(
            header: tr.about,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Text(
                  backendUser!.about,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.42,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // ── Outreach statistics section ──────────────────────────────────────
      children.add(const SizedBox(height: 22));
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr.outreachStatsHeader.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _iosSecondaryLabel(context),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => _openAddOutreachStatsSheet(context),
                child: Text(
                  tr.addOutreachStats,
                  style: TextStyle(
                    fontSize: 14,
                    color: primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (myStatsLoading) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator(radius: 12)),
          ),
        );
      } else if (myStats == null) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _openAddOutreachStatsSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: _iosCardBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.chart_bar_alt_fill,
                      size: 20,
                      color: _iosSecondaryLabel(context),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tr.noStatsYet,
                      style: TextStyle(
                        fontSize: 15,
                        color: _iosSecondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        children.add(
          _ProfileOutreachEntryCard(
            entry: myStats!,
            tr: tr,
            onEdit: () => _openEditOutreachStatsSheet(context),
            onReset: () => _confirmResetStats(context),
            onDeleteTestimony: onDeleteTestimony,
          ),
        );
        children.add(const SizedBox(height: 10));
      }

      children.add(const SizedBox(height: 22));
      children.add(
        _AppleSection(
          children: [
            _AppleListRow(
              icon: CupertinoIcons.rosette,
              iconBackground: const Color(0xFFFF9500),
              iconColor: CupertinoColors.white,
              title: tr.achievements,
              onTap: () => _openAchievementsSheet(context),
            ),
          ],
        ),
      );

      children.add(const SizedBox(height: 22));
      children.add(
        _AppleSection(
          header: tr.accountSection,
          children: [
            _AppleListRow(
              icon: CupertinoIcons.pencil,
              iconBackground: const Color(0xFFAF52DE),
              iconColor: CupertinoColors.white,
              title: tr.editAccountProfile,
              onTap: () async {
                await onEditAccount();
              },
            ),
            _AppleListRow(
              icon: CupertinoIcons.square_arrow_right,
              iconBackground: CupertinoColors.destructiveRed
                  .resolveFrom(context)
                  .withOpacity(0.18),
              iconColor: CupertinoColors.destructiveRed.resolveFrom(context),
              title: tr.signOut,
              destructive: true,
              onTap: () => _confirmLogout(context),
            ),
            if (onDeleteAccount != null)
              _AppleListRow(
                icon: CupertinoIcons.trash_fill,
                iconBackground: CupertinoColors.destructiveRed
                    .resolveFrom(context)
                    .withOpacity(0.18),
                iconColor: CupertinoColors.destructiveRed.resolveFrom(context),
                title: tr.deleteAccountConfirm,
                destructive: true,
                onTap: () => _confirmDeleteAccount(context),
              ),
          ],
        ),
      );
    }

    children.add(const SizedBox(height: 40));

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 110),
        children: children,
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
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

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.12),
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
                            color: Colors.white,
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
                          onPressed: () => _confirmLogout(context),
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
                              onPressed: () => _confirmLogout(context),
                              icon: const Icon(Icons.logout_rounded),
                            ),
                            if (onDeleteAccount != null)
                              IconButton(
                                tooltip: tr.deleteAccountConfirm,
                                onPressed: () => _confirmDeleteAccount(context),
                                icon: Icon(
                                  Icons.delete_forever_rounded,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.12),
                          foregroundImage: _profileAvatarImage(
                            cachedAvatarPath,
                            backendAvatarUrl,
                          ),
                          child:
                              _profileAvatarImage(
                                    cachedAvatarPath,
                                    backendAvatarUrl,
                                  ) ==
                                  null
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
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.workspace_premium_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(tr.achievements),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openAchievementsSheet(context),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  tr.outreachStatsHeader,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openAddOutreachStatsSheet(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tr.addOutreachStats),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (myStatsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (myStats == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tr.noStatsYet,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tr.outreachStatsHeader,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: tr.editOutreachStats,
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            onPressed: () =>
                                _openEditOutreachStatsSheet(context),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            tooltip: tr.resetStats,
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 18,
                            ),
                            onPressed: () => _confirmResetStats(context),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _matStatChip(
                            context,
                            Icons.campaign_rounded,
                            '${myStats!.gospelsTold}',
                            tr.gospelsTold,
                          ),
                          const SizedBox(width: 8),
                          _matStatChip(
                            context,
                            Icons.favorite_rounded,
                            '${myStats!.salvationPrayedUnreachable}',
                            tr.salvationPrayedUnreachable,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _matStatChip(
                            context,
                            Icons.menu_book_rounded,
                            '${myStats!.scripturesDistributed}',
                            tr.scripturesDistributed,
                          ),
                          const SizedBox(width: 8),
                          _matStatChip(
                            context,
                            Icons.health_and_safety_rounded,
                            '${myStats!.healingsDeliverances}',
                            tr.healingsDeliverances,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _matStatChip(
                            context,
                            Icons.mail_rounded,
                            '${myStats!.fathersLettersDistributed}',
                            tr.fathersLettersDistributed,
                          ),
                        ],
                      ),
                      if (myStats!.testimonies.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr.testimonies,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < myStats!.testimonies.length; i++)
                          _OutreachTestimonyCard(
                            text: myStats!.testimonies[i].text,
                            number: myStats!.testimonies.length - i,
                            tint: theme.colorScheme.primary,
                            onDelete: onDeleteTestimony != null
                                ? () => onDeleteTestimony!(
                                    myStats!.testimonies[i].id,
                                  )
                                : null,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _matStatChip(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  void _doSave() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AccountEditResult(
        name: _name.text.trim(),
        about: _about.text.trim(),
        avatarPath: _avatarFile?.path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    Widget avatarPickerButton() {
      if (_isApple) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _pickingAvatar ? null : _pickAvatar,
          child: _pickingAvatar
              ? const CupertinoActivityIndicator()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.photo, size: 18),
                    const SizedBox(width: 6),
                    Text(tr.changeAvatar),
                  ],
                ),
        );
      }
      return OutlinedButton.icon(
        onPressed: _pickingAvatar ? null : _pickAvatar,
        icon: _pickingAvatar
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.photo_library_outlined),
        label: Text(tr.changeAvatar),
      );
    }

    return Container(
      height: mq.size.height * 0.9,
      decoration: BoxDecoration(
        color: _isApple ? _iosBackground(context) : theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_isApple ? 14 : 28),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: _isApple ? 36 : 44,
            height: _isApple ? 5 : 4,
            decoration: BoxDecoration(
              color: _isApple
                  ? CupertinoColors.systemGrey3.resolveFrom(context)
                  : theme.dividerColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (_isApple)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      tr.cancel,
                      style: TextStyle(
                        fontSize: 17,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tr.editAccountProfile,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    onPressed: _doSave,
                    child: Text(
                      tr.save,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
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
                    if (!_isApple) ...[
                      Text(
                        tr.editAccountProfile,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          foregroundImage: _avatarFile != null && !kIsWeb
                              ? FileImage(File(_avatarFile!.path))
                              : null,
                          child: _avatarFile == null
                              ? Text(widget.initial.initials)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        avatarPickerButton(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isApple) ...[
                      CupertinoTextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        placeholder: tr.yourName,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: Icon(
                            CupertinoIcons.person,
                            size: 20,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground.resolveFrom(
                            context,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.separator.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CupertinoTextField(
                        controller: _about,
                        minLines: 3,
                        maxLines: 5,
                        placeholder: tr.bioHint,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground.resolveFrom(
                            context,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.separator.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
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
                    ],
                    if (!_isApple) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _doSave,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(tr.save),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENTS
// ─────────────────────────────────────────────────────────────────────────────

/// Achievements are derived from records the user already maintains. Outreach
/// figures power ministry milestones; believer records power follow-up ones.
class _AchievementsPage extends StatelessWidget {
  final S tr;
  final List<NewBeliever> believers;
  final OutreachStatEntry? stats;
  final bool statsLoading;

  const _AchievementsPage({
    required this.tr,
    required this.believers,
    required this.stats,
    required this.statsLoading,
  });

  bool get _isRussian => tr.lang == AppLanguage.ru;

  int get _savedBelievers => believers
      .where(
        (believer) => believer.stage.index >= BelieverStage.receivedJesus.index,
      )
      .length;

  /// A person added to Believers has necessarily heard the Gospel, so this
  /// source complements the manually recorded outreach total.
  int get _peopleWhoHeardGospel => (stats?.gospelsTold ?? 0) + believers.length;

  int get _believersWithContact => believers
      .where(
        (believer) =>
            believer.phone.trim().isNotEmpty ||
            believer.telegram.trim().isNotEmpty,
      )
      .length;

  int get _inChurch => believers
      .where(
        (believer) =>
            believer.stage.index >= BelieverStage.joinedCommunity.index,
      )
      .length;

  List<_AchievementProgress> _achievements() {
    final outreach = stats;
    final isRussian = _isRussian;
    return [
      _AchievementProgress(
        title: isRussian ? 'Рассказать Евангелие' : 'Share the Gospel',
        source: isRussian
            ? 'По статистике и карточкам Believers'
            : 'From statistics and Believers records',
        icon: _isApple
            ? CupertinoIcons.chat_bubble_2_fill
            : Icons.forum_rounded,
        value: _peopleWhoHeardGospel,
        levels: const [1, 5, 10, 15, 100, 200, 500, 750, 1000, 2000],
      ),
      _AchievementProgress(
        title: isRussian ? 'Спасения' : 'Salvations',
        source: isRussian
            ? 'По статусам в Believers'
            : 'From stages in Believers',
        icon: _isApple ? CupertinoIcons.heart_fill : Icons.favorite_rounded,
        value: _savedBelievers,
        levels: const [1, 5, 10, 20, 50, 100, 200, 500],
      ),
      _AchievementProgress(
        title: isRussian ? 'Исцеления' : 'Healings',
        source: isRussian
            ? 'По личной статистике евангелизации'
            : 'From your outreach statistics',
        icon: _isApple
            ? CupertinoIcons.heart_circle_fill
            : Icons.health_and_safety_rounded,
        value: outreach?.healingsDeliverances ?? 0,
        levels: const [1, 5, 10, 20, 50, 100, 200, 500],
      ),
      _AchievementProgress(
        title: isRussian ? 'Взять контакт' : 'Take a contact',
        source: isRussian
            ? 'По телефонам и Telegram в Believers'
            : 'From phones and Telegram in Believers',
        icon: _isApple
            ? CupertinoIcons.person_crop_circle_badge_plus
            : Icons.person_add_alt_1_rounded,
        value: _believersWithContact,
        levels: const [1, 5, 10, 20, 50, 100, 200, 500],
      ),
      _AchievementProgress(
        title: isRussian
            ? 'Раздать Евангелие от Иоанна'
            : 'Distribute John’s Gospels',
        source: isRussian
            ? 'По личной статистике евангелизации'
            : 'From your outreach statistics',
        icon: _isApple ? CupertinoIcons.book_fill : Icons.menu_book_rounded,
        value: outreach?.scripturesDistributed ?? 0,
        levels: const [1, 5, 10, 20, 50, 100, 200, 500],
      ),
      _AchievementProgress(
        title: isRussian ? 'Пригласить в церковь' : 'Invite to church',
        source: isRussian
            ? 'По вовлечению в церковь в Believers'
            : 'From church involvement in Believers',
        icon: _isApple ? CupertinoIcons.building_2_fill : Icons.church_rounded,
        value: _inChurch,
        levels: const [1, 5, 10, 20, 50, 100, 200, 500],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final achievements = _achievements();
    final milestones = achievements.fold<int>(
      0,
      (sum, achievement) => sum + achievement.levels.length,
    );
    final unlocked = achievements.fold<int>(
      0,
      (sum, achievement) => sum + achievement.unlockedCount,
    );
    final count = NumberFormat.decimalPattern(_isRussian ? 'ru_RU' : 'en_US');

    return Scaffold(
      backgroundColor: _isApple ? _iosBackground(context) : colors.surface,
      appBar: AppBar(
        title: Text(
          tr.achievements,
          style: theme.textTheme.titleLarge?.copyWith(
            color: _isApple
                ? CupertinoColors.label.resolveFrom(context)
                : colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: _isApple,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _AchievementHero(
              title: _isRussian
                  ? 'Путь, который меняет жизни'
                  : 'A journey that changes lives',
              subtitle: _isRussian
                  ? 'Каждое служение открывает новый уровень.'
                  : 'Each act of ministry unlocks a new level.',
              unlocked: unlocked,
              total: milestones,
              isRussian: _isRussian,
              icon: _isApple
                  ? CupertinoIcons.rosette
                  : Icons.workspace_premium_rounded,
            ),
            if (statsLoading) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                label: _isRussian
                    ? 'Обновляем статистику евангелизации'
                    : 'Updating outreach statistics',
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              _isRussian ? 'ВАШИ ДОСТИЖЕНИЯ' : 'YOUR ACHIEVEMENTS',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            ...achievements.map(
              (achievement) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AchievementCard(
                  achievement: achievement,
                  count: count,
                  isRussian: _isRussian,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isRussian
                  ? 'Достижения обновляются автоматически из вашей личной статистики и карточек Believers.'
                  : 'Achievements update automatically from your personal statistics and Believers records.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final int unlocked;
  final int total;
  final bool isRussian;
  final IconData icon;

  const _AchievementHero({
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.total,
    required this.isRussian,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$unlocked / $total',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isRussian ? 'уровней открыто' : 'levels unlocked',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final _AchievementProgress achievement;
  final NumberFormat count;
  final bool isRussian;

  const _AchievementCard({
    required this.achievement,
    required this.count,
    required this.isRussian,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final complete = achievement.isComplete;
    final next = achievement.nextLevel;
    final status = complete
        ? (isRussian ? 'Все уровни открыты' : 'All levels unlocked')
        : (isRussian
              ? 'Следующая цель: ${count.format(next)}'
              : 'Next goal: ${count.format(next)}');

    return Semantics(
      label:
          '${achievement.title}. ${count.format(achievement.value)}. $status',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      achievement.icon,
                      color: colors.onPrimaryContainer,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          achievement.source,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    count.format(achievement.value),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: achievement.progressToNext,
                  minHeight: 7,
                  backgroundColor: colors.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    complete ? colors.tertiary : colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: complete ? colors.tertiary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: achievement.levels.map((level) {
                  final unlocked = achievement.value >= level;
                  final isNext = level == next;
                  return _AchievementLevelChip(
                    level: count.format(level),
                    unlocked: unlocked,
                    isNext: isNext,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementLevelChip extends StatelessWidget {
  final String level;
  final bool unlocked;
  final bool isNext;

  const _AchievementLevelChip({
    required this.level,
    required this.unlocked,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = unlocked
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground = unlocked
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: isNext ? Border.all(color: colors.primary, width: 1.2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked
                ? (_isApple ? CupertinoIcons.check_mark : Icons.check_rounded)
                : (_isApple
                      ? CupertinoIcons.lock_fill
                      : Icons.lock_outline_rounded),
            size: 13,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            level,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementProgress {
  final String title;
  final String source;
  final IconData icon;
  final int value;
  final List<int> levels;

  const _AchievementProgress({
    required this.title,
    required this.source,
    required this.icon,
    required this.value,
    required this.levels,
  });

  int get unlockedCount => levels.where((level) => value >= level).length;
  bool get isComplete => unlockedCount == levels.length;
  int? get nextLevel => isComplete ? null : levels[unlockedCount];

  double get progressToNext {
    if (isComplete) return 1;
    final previous = unlockedCount == 0 ? 0 : levels[unlockedCount - 1];
    final next = nextLevel!;
    return ((value - previous) / (next - previous)).clamp(0, 1).toDouble();
  }
}
