part of '../main.dart';

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
              if (_isApple)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onSettings,
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
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
            child: _isApple
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                    child: Text(
                      lang == AppLanguage.ru ? 'Удалить' : 'Delete',
                      style: const TextStyle(
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                  )
                : TextButton.icon(
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
            _isApple
                ? CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(12),
                    onPressed: onAdd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.add, size: 18),
                        const SizedBox(width: 6),
                        Text(tr.add),
                      ],
                    ),
                  )
                : FilledButton.icon(
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
