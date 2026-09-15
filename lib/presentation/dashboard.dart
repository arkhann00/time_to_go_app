part of '../main.dart';

class DashboardPage extends StatefulWidget {
  final S tr;
  final List<LatestTestimony> latestTestimonies;
  final bool loading;
  final bool summaryLoading;
  final SummaryStats? generalSummary;
  final SummaryStats? personalSummary;
  final bool isAuthenticated;
  final VoidCallback onSettings;
  final Future<void> Function() onRefresh;
  final Future<void> Function({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
    required int fathersLettersDistributed,
    required int healingsDeliverances,
    String? testimony,
  })?
  onAddOutreachStats;

  const DashboardPage({
    super.key,
    required this.tr,
    required this.latestTestimonies,
    required this.loading,
    required this.summaryLoading,
    required this.generalSummary,
    required this.personalSummary,
    required this.isAuthenticated,
    required this.onSettings,
    required this.onRefresh,
    this.onAddOutreachStats,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _showPersonal = false;

  @override
  Widget build(BuildContext context) {
    if (_isApple) return _buildApple(context);
    return _buildMaterial(context);
  }

  Widget _buildApple(BuildContext context) {
    final tr = widget.tr;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final latest = widget.latestTestimonies.isEmpty
        ? null
        : widget.latestTestimonies.first;
    final hasLatest = latest != null;
    final needsPreview = latest != null && _needsTestimonyPreview(latest.text);
    final showPersonal = _showPersonal;
    final summary = showPersonal
        ? widget.personalSummary
        : widget.generalSummary;

    return RefreshIndicator.adaptive(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 110),
        children: [
          _AppleLargeTitle(
            title: tr.appTitle,
            subtitle: tr.homeWitnessSub,
            onSettings: widget.onSettings,
          ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else ...[
            _AppleTestimonyHero(
              tint: primary,
              label: tr.latestTestimony,
              text: latest == null
                  ? tr.noLatestTestimonies
                  : _testimonyPreview(latest.text),
              author: latest?.author,
              addedByName: latest?.addedByName,
              addedByAvatarUrl: latest?.addedByAvatarUrl,
              showFullLabel: needsPreview ? tr.showFull : null,
              onTap: hasLatest
                  ? () => _openLatestTestimoniesSheet(context)
                  : null,
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                tr.statisticsHeader.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _iosSecondaryLabel(context),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<bool>(
                groupValue: _showPersonal,
                children: {
                  false: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      tr.generalStats,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  true: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.isAuthenticated) ...[
                          Icon(
                            CupertinoIcons.lock_fill,
                            size: 11,
                            color: _showPersonal
                                ? CupertinoColors.label.resolveFrom(context)
                                : _iosSecondaryLabel(context),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tr.personalStats,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                },
                onValueChanged: (v) =>
                    setState(() => _showPersonal = v ?? false),
              ),
            ),
            const SizedBox(height: 14),
            if (widget.summaryLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CupertinoActivityIndicator(radius: 13)),
              )
            else if (showPersonal && widget.personalSummary == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: _iosCardBackground(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.lock_fill,
                        size: 28,
                        color: _iosSecondaryLabel(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr.personalStatsUnavailable,
                        style: TextStyle(
                          color: _iosSecondaryLabel(context),
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (summary != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SummaryStatsCard(
                  summary: summary,
                  tr: tr,
                  tint: primary,
                ),
              ),
            if (widget.onAddOutreachStats != null &&
                !widget.summaryLoading) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _openAddSheet(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _iosCardBackground(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.plus_circle,
                          size: 16,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr.addOutreachStats,
                          style: TextStyle(
                            fontSize: 14,
                            color: primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final tr = widget.tr;
    final theme = Theme.of(context);
    final latest = widget.latestTestimonies.isEmpty
        ? null
        : widget.latestTestimonies.first;
    final hasLatest = latest != null;
    final needsPreview = latest != null && _needsTestimonyPreview(latest.text);
    final showPersonal = _showPersonal;
    final summary = showPersonal
        ? widget.personalSummary
        : widget.generalSummary;

    return RefreshIndicator.adaptive(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _PageHeader(
            title: tr.appTitle,
            subtitle: tr.homeWitnessSub,
            onSettings: widget.onSettings,
          ),
          const SizedBox(height: 16),
          if (widget.loading)
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
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: hasLatest
                        ? () => _openLatestTestimoniesSheet(context)
                        : null,
                    child: Container(
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
                              Expanded(
                                child: Text(
                                  tr.latestTestimony,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (hasLatest)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '”${latest == null ? tr.noLatestTestimonies : _testimonyPreview(latest.text)}”',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.38,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (needsPreview)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () =>
                                    _openLatestTestimoniesSheet(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(top: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(tr.showFull),
                              ),
                            ),
                          if ((latest?.addedByName?.isNotEmpty == true) ||
                              (latest?.author?.isNotEmpty == true)) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.15),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    (latest!.addedByName?.isNotEmpty == true
                                        ? latest.addedByName
                                        : latest.author)!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  tr.statisticsHeader,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(tr.generalStats)),
                    ButtonSegment(
                      value: true,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.isAuthenticated) ...[
                            const Icon(Icons.lock_outline_rounded, size: 13),
                            const SizedBox(width: 4),
                          ],
                          Text(tr.personalStats),
                        ],
                      ),
                    ),
                  ],
                  selected: {_showPersonal},
                  onSelectionChanged: (s) =>
                      setState(() => _showPersonal = s.first),
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.summaryLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (showPersonal && widget.personalSummary == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 28,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr.personalStatsUnavailable,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (summary != null)
                  _SummaryStatsCardMaterial(
                    summary: summary,
                    tr: tr,
                    theme: theme,
                  ),
                if (widget.onAddOutreachStats != null &&
                    !widget.summaryLoading) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => _openAddSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(widget.tr.addOutreachStats),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                      ),
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    final onSave = widget.onAddOutreachStats;
    if (onSave == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OutreachStatsSheet(
        tr: widget.tr,
        existing: null,
        onSave:
            ({
              required int gospelsTold,
              required int salvationPrayedUnreachable,
              required int scripturesDistributed,
              required int fathersLettersDistributed,
              required int healingsDeliverances,
              String? testimony,
            }) => onSave(
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

  void _openLatestTestimoniesSheet(BuildContext context) {
    if (widget.latestTestimonies.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LatestTestimoniesSheet(
        tr: widget.tr,
        items: widget.latestTestimonies,
      ),
    );
  }
}

// ── Outreach Testimony Card (used in statistics tab) ─────────────────────────

class _OutreachTestimonyCard extends StatelessWidget {
  final String text;
  final int number;
  final Color tint;
  final Future<void> Function()? onDelete;

  const _OutreachTestimonyCard({
    required this.text,
    required this.number,
    required this.tint,
    this.onDelete,
  });

  void _showActions(BuildContext context) {
    final canDelete = onDelete != null;
    if (!canDelete) return;

    if (_isApple) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => CupertinoActionSheet(
          actions: [
            if (canDelete)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  _confirmDelete(context);
                },
                child: const Text('Удалить'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Удалить',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDelete(context);
                  },
                ),
            ],
          ),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    if (_isApple) {
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Удалить свидетельство?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                onDelete!();
              },
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Удалить свидетельство?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                onDelete!();
              },
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = _isApple
        ? _iosCardBackground(context)
        : Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.35);
    final secondary = _isApple
        ? _iosSecondaryLabel(context)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final labelColor = _isApple
        ? CupertinoColors.label.resolveFrom(context)
        : Theme.of(context).colorScheme.onSurface;
    final canAct = onDelete != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: canAct ? () => _showActions(context) : null,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.14 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -6,
                  child: IgnorePointer(
                    child: Text(
                      '“',
                      style: TextStyle(
                        fontSize: 110,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: tint.withOpacity(isDark ? 0.10 : 0.07),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tint.withOpacity(isDark ? 0.18 : 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$number',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tint,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: labelColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canAct)
                        GestureDetector(
                          onTap: () => _showActions(context),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
                            child: Icon(
                              _isApple
                                  ? CupertinoIcons.ellipsis_circle
                                  : Icons.more_vert_rounded,
                              size: 20,
                              color: secondary,
                            ),
                          ),
                        ),
                    ],
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

// ── Testimony edit sheet ──────────────────────────────────────────────────────

class _TestimonyEditSheet extends StatefulWidget {
  final String initialText;
  final Future<void> Function(String newText) onSave;

  const _TestimonyEditSheet({required this.initialText, required this.onSave});

  @override
  State<_TestimonyEditSheet> createState() => _TestimonyEditSheetState();
}

class _TestimonyEditSheetState extends State<_TestimonyEditSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || text == widget.initialText) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: _iosBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Редактировать свидетельство',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _isApple
                        ? CupertinoColors.label.resolveFrom(context)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (_isApple)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CupertinoActivityIndicator()
                      : const Text(
                          'Сохранить',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isApple)
            CupertinoTextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _iosCardBackground(context),
                borderRadius: BorderRadius.circular(10),
              ),
              autofocus: true,
            )
          else
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              autofocus: true,
            ),
          if (!_isApple) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── iOS Summary Stats Card ───────────────────────────────────────────────────

class _SummaryStatsCard extends StatelessWidget {
  final SummaryStats summary;
  final S tr;
  final Color tint;
  const _SummaryStatsCard({
    required this.summary,
    required this.tr,
    required this.tint,
  });

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Column(
      children: [
        // ── Hero: split two big numbers ────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tint, tint.withOpacity(0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.chart_bar_alt_fill,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr.outreachStatsHeader,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmt(summary.totalSalvation),
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr.totalSalvation,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.82),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: 1,
                        height: double.infinity,
                        color: Colors.white.withOpacity(0.28),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmt(summary.totalSaved),
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withOpacity(0.92),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr.totalSaved,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.82),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Contacts + Scriptures ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: CupertinoIcons.phone_fill,
                color: const Color(0xFF34C759),
                value: _fmt(summary.contactsTaken),
                label: tr.contactsTaken,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(
                context,
                icon: CupertinoIcons.book_fill,
                color: const Color(0xFFFF9500),
                value: _fmt(summary.scripturesDistributed),
                label: tr.scripturesDistributed,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Father's Letters + Healings ────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: CupertinoIcons.envelope_fill,
                color: const Color(0xFF007AFF),
                value: _fmt(summary.fathersLettersDistributed),
                label: tr.fathersLettersDistributed,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(
                context,
                icon: CupertinoIcons.waveform_path_ecg,
                color: const Color(0xFF5856D6),
                value: _fmt(summary.healingsDeliverances),
                label: tr.healingsDeliverances,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: _iosCardBackground(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _iosSecondaryLabel(context),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Material Summary Stats Card ──────────────────────────────────────────────

class _SummaryStatsCardMaterial extends StatelessWidget {
  final SummaryStats summary;
  final S tr;
  final ThemeData theme;
  const _SummaryStatsCardMaterial({
    required this.summary,
    required this.tr,
    required this.theme,
  });

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    return Column(
      children: [
        // ── Hero: split two big numbers ────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, primary.withOpacity(0.74)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tr.outreachStatsHeader,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmt(summary.totalSalvation),
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr.totalSalvation,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.82),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: 1,
                        height: double.infinity,
                        color: Colors.white.withOpacity(0.28),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fmt(summary.totalSaved),
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withOpacity(0.92),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr.totalSaved,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.82),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Contacts + Scriptures ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: Icons.phone_in_talk_rounded,
                color: const Color(0xFF34C759),
                value: _fmt(summary.contactsTaken),
                label: tr.contactsTaken,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(
                context,
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFFF9500),
                value: _fmt(summary.scripturesDistributed),
                label: tr.scripturesDistributed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Father's Letters + Healings ───────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: Icons.mail_rounded,
                color: const Color(0xFF007AFF),
                value: _fmt(summary.fathersLettersDistributed),
                label: tr.fathersLettersDistributed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(
                context,
                icon: Icons.health_and_safety_rounded,
                color: const Color(0xFF5856D6),
                value: _fmt(summary.healingsDeliverances),
                label: tr.healingsDeliverances,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
