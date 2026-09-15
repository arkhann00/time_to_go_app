part of '../main.dart';

class BelieversPage extends StatelessWidget {
  final S tr;
  final List<NewBeliever> believers;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<NewBeliever> onDelete;
  final void Function(NewBeliever, BelieverStage) onStage;
  final VoidCallback onSettings;
  final Future<void> Function() onRefresh;
  const BelieversPage({
    super.key,
    required this.tr,
    required this.believers,
    required this.loading,
    required this.onAdd,
    required this.onDelete,
    required this.onStage,
    required this.onSettings,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (_isApple) return _buildApple(context);
    return _buildMaterial(context);
  }

  Widget _buildApple(BuildContext context) {
    final children = <Widget>[
      _AppleLargeTitle(
        title: tr.believers,
        subtitle: tr.believersSub,
        onSettings: onSettings,
      ),
    ];

    // Legend section
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: BelieverStage.values
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _LegendChip(stage: s, lang: tr.lang),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );

    if (loading) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CupertinoActivityIndicator(radius: 14)),
        ),
      );
    } else if (believers.isEmpty) {
      children.add(const SizedBox(height: 16));
      children.add(_Empty(tr: tr, onAdd: onAdd));
    } else {
      children.add(const SizedBox(height: 8));
      children.add(
        _AppleSection(
          header: tr.list,
          children: believers
              .map(
                (b) => _AppleBelieverRow(
                  item: b,
                  lang: tr.lang,
                  onDelete: () => onDelete(b),
                  onStage: (s) => onStage(b, s),
                ),
              )
              .toList(),
        ),
      );
    }
    children.add(const SizedBox(height: 110));

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8),
        children: children,
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}

/// iOS-style expandable row for a single believer.
class _AppleBelieverRow extends StatefulWidget {
  final NewBeliever item;
  final AppLanguage lang;
  final VoidCallback onDelete;
  final ValueChanged<BelieverStage> onStage;
  const _AppleBelieverRow({
    required this.item,
    required this.lang,
    required this.onDelete,
    required this.onStage,
  });

  @override
  State<_AppleBelieverRow> createState() => _AppleBelieverRowState();
}

class _AppleBelieverRowState extends State<_AppleBelieverRow> {
  bool _expanded = false;

  Future<void> _confirmDelete() async {
    final tr = S(widget.lang);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          widget.lang == AppLanguage.ru ? 'Удалить запись?' : 'Delete entry?',
        ),
        content: Text(widget.item.name),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(widget.lang == AppLanguage.ru ? 'Удалить' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }

  void _showStagePicker() {
    final tr = S(widget.lang);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr.stage),
        actions: BelieverStage.values
            .map(
              (s) => CupertinoActionSheetAction(
                isDefaultAction: s == widget.item.stage,
                onPressed: () {
                  widget.onStage(s);
                  Navigator.of(ctx).pop();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dot(stage: s, size: 10),
                    const SizedBox(width: 10),
                    Text(stageFull(s, widget.lang)),
                  ],
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr.cancel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = S(widget.lang);
    final stageColorVal = stageColor(widget.item.stage);
    final item = widget.item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: stageColorVal.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _Dot(stage: item.stage, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stageShort(item.stage, widget.lang),
                        style: TextStyle(
                          fontSize: 13,
                          color: _iosSecondaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      icon: CupertinoIcons.calendar,
                      text: fmtDate(item.createdAt, widget.lang),
                    ),
                    if (item.telegram.isNotEmpty)
                      _Pill(
                        icon: CupertinoIcons.paperplane,
                        text: item.telegram,
                        onTap: () => openTelegram(item.telegram),
                      ),
                    if (item.phone.isNotEmpty)
                      _Pill(
                        icon: CupertinoIcons.phone,
                        text: formatPhoneForDisplay(item.phone),
                        onTap: () => callPhone(item.phone),
                      ),
                    if (item.place != null && item.place!.isNotEmpty)
                      _Pill(
                        icon: CupertinoIcons.location_solid,
                        text: item.place!,
                      )
                    else if (item.hasLocation)
                      _Pill(
                        icon: CupertinoIcons.location_solid,
                        text:
                            '${item.latitude!.toStringAsFixed(3)}, ${item.longitude!.toStringAsFixed(3)}',
                      ),
                    _Pill(
                      icon: CupertinoIcons.book,
                      text:
                          item.evangelismMethod == EvangelismMethod.custom &&
                              item.customEvangelismMethod.isNotEmpty
                          ? item.customEvangelismMethod
                          : evangelismMethodLabel(
                              item.evangelismMethod,
                              S(widget.lang),
                            ),
                    ),
                  ],
                ),
                if (item.testimony.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.testimony,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.note,
                    style: TextStyle(
                      fontSize: 14,
                      color: _iosSecondaryLabel(context),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: _showStagePicker,
                        child: Text(
                          tr.stage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      color: CupertinoColors.destructiveRed
                          .resolveFrom(context)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      onPressed: _confirmDelete,
                      child: Icon(
                        CupertinoIcons.delete,
                        size: 18,
                        color: CupertinoColors.destructiveRed.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }
}
