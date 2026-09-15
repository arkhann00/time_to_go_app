part of '../main.dart';

class SettingsSheet extends StatefulWidget {
  final S tr;
  final AppThemeMode themeMode;
  final AppLanguage language;
  final bool isAuthenticated;
  final ValueChanged<AppThemeMode> onTheme;
  final ValueChanged<AppLanguage> onLang;
  final Future<void> Function()? onAuthAction;
  final BackendApi backendApi;
  const SettingsSheet({
    super.key,
    required this.tr,
    required this.themeMode,
    required this.language,
    required this.isAuthenticated,
    required this.onTheme,
    required this.onLang,
    this.onAuthAction,
    required this.backendApi,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late AppThemeMode _themeMode;
  late AppLanguage _language;
  bool _authBusy = false;
  bool _fridayReminder = false;
  TimeOfDay _fridayTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _language = widget.language;
    if (widget.isAuthenticated) _loadNotifications();
  }

  String get _reminderLabel => _language == AppLanguage.ru
      ? 'Субботнее напоминание приглашения в церковь'
      : 'Saturday reminder to invite to church';
  String get _timeLabel =>
      _language == AppLanguage.ru ? 'Время напоминания' : 'Reminder time';
  Future<void> _loadNotifications() async {
    try {
      final m = await widget.backendApi.getNotificationSettings();
      final raw = m['believers_friday_reminder_time'] as String? ?? '18:00';
      final p = raw.split(':');
      if (mounted)
        setState(() {
          _fridayReminder = m['believers_friday_reminder_enabled'] == true;
          _fridayTime = TimeOfDay(
            hour: int.tryParse(p[0]) ?? 18,
            minute: int.tryParse(p.length > 1 ? p[1] : '') ?? 0,
          );
        });
    } catch (_) {}
  }

  Future<void> _saveNotifications() async {
    if (!widget.isAuthenticated) return;
    try {
      await widget.backendApi.patchNotificationSettings(
        believersFridayReminderEnabled: _fridayReminder,
        believersFridayReminderTime:
            '${_fridayTime.hour.toString().padLeft(2, '0')}:${_fridayTime.minute.toString().padLeft(2, '0')}',
      );
    } catch (_) {}
  }

  Future<TimeOfDay?> _pickReminderTime(BuildContext context) async {
    if (!_isApple) {
      return showTimePicker(context: context, initialTime: _fridayTime);
    }

    var selectedTime = _fridayTime;
    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(S(_language).cancel),
                    ),
                    CupertinoButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(selectedTime),
                      child: Text(S(_language).done),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                  initialDateTime: DateTime(
                    2024,
                    1,
                    1,
                    _fridayTime.hour,
                    _fridayTime.minute,
                  ),
                  onDateTimeChanged: (dateTime) {
                    selectedTime = TimeOfDay.fromDateTime(dateTime);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationControls(BuildContext context) => Column(
    children: [
      SwitchListTile.adaptive(
        title: Text(_reminderLabel),
        value: _fridayReminder,
        onChanged: widget.isAuthenticated
            ? (v) {
                setState(() => _fridayReminder = v);
                _saveNotifications();
              }
            : null,
      ),
      ListTile(
        title: Text(_timeLabel),
        trailing: Text(_fridayTime.format(context)),
        enabled: widget.isAuthenticated && _fridayReminder,
        onTap: () async {
          final picked = await _pickReminderTime(context);
          if (picked != null) {
            setState(() => _fridayTime = picked);
            _saveNotifications();
          }
        },
      ),
    ],
  );

  Widget _buildThemeControl(S tr, ThemeData theme) {
    if (_isApple) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.themeLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<AppThemeMode>(
              groupValue: _themeMode,
              children: {
                AppThemeMode.system: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tr.sys, style: const TextStyle(fontSize: 13)),
                ),
                AppThemeMode.light: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tr.light, style: const TextStyle(fontSize: 13)),
                ),
                AppThemeMode.dark: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tr.dark, style: const TextStyle(fontSize: 13)),
                ),
              },
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _themeMode = v);
                widget.onTheme(v);
              },
            ),
          ),
        ],
      );
    }
    return Column(
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
              label: Text(tr.sys, style: const TextStyle(fontSize: 13)),
              icon: const Icon(Icons.brightness_auto_rounded),
            ),
            ButtonSegment(
              value: AppThemeMode.light,
              label: Text(tr.light, style: const TextStyle(fontSize: 13)),
              icon: const Icon(Icons.light_mode_rounded),
            ),
            ButtonSegment(
              value: AppThemeMode.dark,
              label: Text(tr.dark, style: const TextStyle(fontSize: 13)),
              icon: const Icon(Icons.dark_mode_rounded),
            ),
          ],
          selected: {_themeMode},
          onSelectionChanged: (v) {
            setState(() => _themeMode = v.first);
            widget.onTheme(v.first);
          },
        ),
      ],
    );
  }

  Widget _buildLangControl(S tr, ThemeData theme) {
    if (_isApple) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.langLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<AppLanguage>(
              groupValue: _language,
              children: const {
                AppLanguage.ru: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Русский', style: TextStyle(fontSize: 13)),
                ),
                AppLanguage.en: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('English', style: TextStyle(fontSize: 13)),
                ),
              },
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _language = v);
                widget.onLang(v);
              },
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              label: Text('Русский', style: TextStyle(fontSize: 13)),
            ),
            ButtonSegment(
              value: AppLanguage.en,
              label: Text('English', style: TextStyle(fontSize: 13)),
            ),
          ],
          selected: {_language},
          onSelectionChanged: (v) {
            setState(() => _language = v.first);
            widget.onLang(v.first);
          },
        ),
      ],
    );
  }

  Widget _buildAuthButton(S tr, ThemeData theme) {
    if (widget.onAuthAction == null) return const SizedBox.shrink();

    void handleAuth() async {
      setState(() => _authBusy = true);
      Navigator.of(context).pop();
      try {
        await widget.onAuthAction!.call();
      } finally {
        if (mounted) setState(() => _authBusy = false);
      }
    }

    if (_isApple) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: _authBusy ? null : handleAuth,
          borderRadius: BorderRadius.circular(12),
          child: _authBusy
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Text(widget.isAuthenticated ? tr.signOut : tr.signIn),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _authBusy ? null : handleAuth,
        icon: Icon(
          widget.isAuthenticated ? Icons.logout_rounded : Icons.login_rounded,
        ),
        label: Text(widget.isAuthenticated ? tr.signOut : tr.signIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isApple) return _buildApple(context);
    return _buildMaterial(context);
  }

  Widget _buildApple(BuildContext context) {
    final tr = widget.tr;
    final mq = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      decoration: BoxDecoration(
        color: _iosBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3.resolveFrom(context),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr.settings,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    tr.done,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Column(
                children: [
                  _AppleSection(
                    header: tr.appearance,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr.themeLabel,
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: CupertinoSlidingSegmentedControl<AppThemeMode>(
                            groupValue: _themeMode,
                            children: {
                              AppThemeMode.system: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  tr.sys,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              AppThemeMode.light: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  tr.light,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              AppThemeMode.dark: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  tr.dark,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            },
                            onValueChanged: (v) {
                              if (v == null) return;
                              setState(() => _themeMode = v);
                              widget.onTheme(v);
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr.langLabel,
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: SizedBox(
                          width: double.infinity,
                          child: CupertinoSlidingSegmentedControl<AppLanguage>(
                            groupValue: _language,
                            children: const {
                              AppLanguage.ru: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'Русский',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              AppLanguage.en: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'English',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            },
                            onValueChanged: (v) {
                              if (v == null) return;
                              setState(() => _language = v);
                              widget.onLang(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.isAuthenticated) ...[
                    const SizedBox(height: 18),
                    _AppleSection(
                      header: _language == AppLanguage.ru
                          ? 'УВЕДОМЛЕНИЯ'
                          : 'NOTIFICATIONS',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: _notificationControls(context),
                        ),
                      ],
                    ),
                  ],
                  if (widget.onAuthAction != null) ...[
                    const SizedBox(height: 18),
                    _AppleSection(
                      header: tr.accountSection,
                      children: [
                        _AppleListRow(
                          icon: widget.isAuthenticated
                              ? CupertinoIcons.square_arrow_right
                              : CupertinoIcons.person_crop_circle_badge_plus,
                          iconBackground: widget.isAuthenticated
                              ? CupertinoColors.destructiveRed
                                    .resolveFrom(context)
                                    .withOpacity(0.18)
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.18),
                          iconColor: widget.isAuthenticated
                              ? CupertinoColors.destructiveRed.resolveFrom(
                                  context,
                                )
                              : Theme.of(context).colorScheme.primary,
                          title: widget.isAuthenticated
                              ? tr.signOut
                              : tr.signIn,
                          destructive: widget.isAuthenticated,
                          onTap: _authBusy
                              ? null
                              : () async {
                                  setState(() => _authBusy = true);
                                  Navigator.of(context).pop();
                                  try {
                                    await widget.onAuthAction!.call();
                                  } finally {
                                    if (mounted) {
                                      setState(() => _authBusy = false);
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
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
                          _buildThemeControl(tr, theme),
                          const SizedBox(height: 24),
                          _buildLangControl(tr, theme),
                          const SizedBox(height: 24),
                          if (widget.isAuthenticated) ...[
                            _notificationControls(context),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            tr.account,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildAuthButton(tr, theme),
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

class _ProfileOutreachEntryCard extends StatelessWidget {
  final OutreachStatEntry entry;
  final S tr;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final Future<void> Function(int id)? onDeleteTestimony;

  const _ProfileOutreachEntryCard({
    required this.entry,
    required this.tr,
    required this.onEdit,
    required this.onReset,
    this.onDeleteTestimony,
  });

  @override
  Widget build(BuildContext context) {
    final tint = CupertinoColors.activeBlue.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _iosCardBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        tr.outreachStatsHeader,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: onEdit,
                        child: Icon(
                          CupertinoIcons.pencil,
                          size: 18,
                          color: tint,
                        ),
                      ),
                      const SizedBox(width: 4),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: onReset,
                        child: Icon(
                          CupertinoIcons.arrow_counterclockwise,
                          size: 18,
                          color: CupertinoColors.destructiveRed.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStatItem(
                              icon: CupertinoIcons.bubble_left_fill,
                              color: const Color(0xFF34C759),
                              value: '${entry.gospelsTold}',
                              label: tr.gospelsTold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniStatItem(
                              icon: CupertinoIcons.heart_fill,
                              color: const Color(0xFFFF3B30),
                              value: '${entry.salvationPrayedUnreachable}',
                              label: tr.salvationPrayedUnreachable,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStatItem(
                              icon: CupertinoIcons.book_fill,
                              color: const Color(0xFFFF9500),
                              value: '${entry.scripturesDistributed}',
                              label: tr.scripturesDistributed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniStatItem(
                              icon: CupertinoIcons.waveform_path_ecg,
                              color: const Color(0xFF5856D6),
                              value: '${entry.healingsDeliverances}',
                              label: tr.healingsDeliverances,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStatItem(
                              icon: CupertinoIcons.envelope_fill,
                              color: const Color(0xFF007AFF),
                              value: '${entry.fathersLettersDistributed}',
                              label: tr.fathersLettersDistributed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (entry.testimonies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                tr.testimonies.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _iosSecondaryLabel(context),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (int i = 0; i < entry.testimonies.length; i++)
              _OutreachTestimonyCard(
                text: entry.testimonies[i].text,
                number: entry.testimonies.length - i,
                tint: tint,
                onDelete: onDeleteTestimony != null
                    ? () => onDeleteTestimony!(entry.testimonies[i].id)
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}
