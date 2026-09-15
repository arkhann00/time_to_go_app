part of '../main.dart';

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
                child: _isApple
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          lang == AppLanguage.ru ? 'Закрыть' : 'Close',
                        ),
                      )
                    : TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          lang == AppLanguage.ru ? 'Закрыть' : 'Close',
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

class LatestTestimoniesSheet extends StatelessWidget {
  final S tr;
  final List<LatestTestimony> items;
  const LatestTestimoniesSheet({
    super.key,
    required this.tr,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final secondary = _iosSecondaryLabel(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final mq = MediaQuery.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.82),
          decoration: BoxDecoration(
            color: bg.withOpacity(isDark ? 0.88 : 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondary.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                child: Row(
                  children: [
                    // Squircle icon — mirrors _AppleTestimonyHero
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        CupertinoIcons.book_fill,
                        size: 16,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr.latestTestimoniesTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: labelColor,
                        ),
                      ),
                    ),
                    // iOS-style close button (circle × )
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      minSize: 36,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: secondary.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 14,
                          color: secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Thin separator ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(height: 0.5, color: _iosSeparator(context)),
              ),

              // ── Cards list ───────────────────────────────────────────────
              Flexible(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    mq.viewPadding.bottom + 24,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final number = items.length - index;
                    return _TestimonyCard(
                      item: item,
                      number: number,
                      tint: primary,
                      isDark: isDark,
                      secondary: secondary,
                      labelColor: labelColor,
                    );
                  },
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

class _TestimonyCard extends StatelessWidget {
  final LatestTestimony item;
  final int number;
  final Color tint;
  final bool isDark;
  final Color secondary;
  final Color labelColor;

  const _TestimonyCard({
    required this.item,
    required this.number,
    required this.tint,
    required this.isDark,
    required this.secondary,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = _iosCardBackground(context);
    final dateStr = DateFormat('d MMM yyyy').format(item.createdAt);
    final displayName = item.addedByName?.isNotEmpty == true
        ? item.addedByName
        : (item.author?.isNotEmpty == true ? item.author : null);
    final hasAuthor = displayName != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ── Decorative giant quote glyph (same trick as _AppleTestimonyHero)
              Positioned(
                top: -24,
                right: -8,
                child: IgnorePointer(
                  child: Text(
                    '\u201C',
                    style: TextStyle(
                      fontSize: 140,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: tint.withOpacity(isDark ? 0.10 : 0.07),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: date badge + number ──────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tint.withOpacity(isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tint,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '#$number',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: secondary.withOpacity(0.55),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Quote text ────────────────────────────────────────
                    Text(
                      '\u201C${item.text}\u201D',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: labelColor,
                      ),
                    ),

                    // ── Author ────────────────────────────────────────────
                    if (hasAuthor) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: tint.withOpacity(
                              isDark ? 0.20 : 0.12,
                            ),
                            foregroundImage:
                                item.addedByAvatarUrl != null &&
                                    item.addedByAvatarUrl!.isNotEmpty
                                ? NetworkImage(item.addedByAvatarUrl!)
                                : null,
                            child:
                                (item.addedByAvatarUrl == null ||
                                    item.addedByAvatarUrl!.isEmpty)
                                ? Icon(
                                    CupertinoIcons.person_fill,
                                    size: 12,
                                    color: tint,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              displayName!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tint,
                                letterSpacing: -0.1,
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
