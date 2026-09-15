part of '../main.dart';

bool get _isApple =>
    kIsWeb || Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

ImageProvider? _profileAvatarImage(String? localPath, String? networkUrl) {
  if (!kIsWeb &&
      localPath != null &&
      localPath.isNotEmpty &&
      File(localPath).existsSync()) {
    return FileImage(File(localPath));
  }
  if (networkUrl != null && networkUrl.isNotEmpty) {
    return NetworkImage(networkUrl);
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS DESIGN HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color _iosBackground(BuildContext context) {
  return CupertinoColors.systemGroupedBackground.resolveFrom(context);
}

Color _iosCardBackground(BuildContext context) {
  return CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
}

Color _iosSeparator(BuildContext context) {
  return CupertinoColors.separator.resolveFrom(context);
}

Color _iosSecondaryLabel(BuildContext context) {
  return CupertinoColors.secondaryLabel.resolveFrom(context);
}

/// iOS-style grouped list section: rounded background with subtle inner dividers.
class _AppleSection extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  final String? footer;
  final double dividerIndent;
  const _AppleSection({
    required this.children,
    this.header,
    this.footer,
    this.dividerIndent = 16,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = _iosSecondaryLabel(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          Padding(
            padding: EdgeInsetsDirectional.only(start: dividerIndent),
            child: Container(height: 0.5, color: _iosSeparator(context)),
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 6),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  color: secondary,
                  letterSpacing: -0.08,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: _iosCardBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 0),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 12,
                  color: secondary,
                  height: 1.32,
                  letterSpacing: -0.08,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTREACH STATISTICS MODELS
// ─────────────────────────────────────────────────────────────────────────────
class _AppleInputRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconBackground;
  final String placeholder;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int maxLines;
  final bool autocorrect;

  const _AppleInputRow({
    this.icon,
    this.iconBackground,
    required this.placeholder,
    required this.controller,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.autocorrect = true,
  });

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final placeholderColor = CupertinoColors.placeholderText.resolveFrom(
      context,
    );

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType:
          keyboardType ??
          (multiline ? TextInputType.multiline : TextInputType.text),
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      autocorrect: autocorrect,
      cursorColor: Theme.of(context).colorScheme.primary,
      style: TextStyle(fontSize: 17, color: labelColor, letterSpacing: -0.3),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(
          icon == null ? 16 : 0,
          multiline ? 12 : 14,
          16,
          multiline ? 12 : 14,
        ),
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        iconBackground ??
                        CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: CupertinoColors.white),
                ),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: placeholder,
        hintStyle: TextStyle(
          fontSize: 17,
          color: placeholderColor,
          letterSpacing: -0.3,
        ),
        errorStyle: TextStyle(
          fontSize: 12,
          color: CupertinoColors.destructiveRed.resolveFrom(context),
        ),
      ),
    );
  }
}

/// Item descriptor for the modern Apple glass tab bar.
class _AppleTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _AppleTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Modern iOS-18-style floating glass tab bar with blurred background,
/// soft elevation, animated selection pill and SF-style label scaling.
class _AppleGlassTabBar extends StatelessWidget {
  final List<_AppleTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color tint;

  const _AppleGlassTabBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // Translucent material body. The bar floats and clears the screen edge.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        bottomInset > 0 ? bottomInset + 4 : 14,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color:
                  (isDark
                          ? const Color(0xFF1C1C1E)
                          : CupertinoColors.systemBackground.resolveFrom(
                              context,
                            ))
                      .withOpacity(isDark ? 0.72 : 0.78),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.10),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(items.length, (i) {
                  return Expanded(
                    child: _AppleGlassTab(
                      item: items[i],
                      selected: i == currentIndex,
                      tint: tint,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single tab in the glass bar — animated icon swap + pill highlight.
class _AppleGlassTab extends StatelessWidget {
  final _AppleTabItem item;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  const _AppleGlassTab({
    required this.item,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final color = selected ? tint : inactiveColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? tint.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                key: ValueKey<bool>(selected),
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS form row used for pickers: title, current value, chevron.
class _AppleTapRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconBackground;
  final String title;
  final String? value;
  final String? placeholder;
  final VoidCallback onTap;
  final Widget? trailingExtra;

  const _AppleTapRow({
    this.icon,
    this.iconBackground,
    required this.title,
    this.value,
    this.placeholder,
    required this.onTap,
    this.trailingExtra,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = _iosSecondaryLabel(context);
    final hasValue = value != null && value!.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color:
                      iconBackground ??
                      CupertinoColors.systemGrey5.resolveFrom(context),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: CupertinoColors.white),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  color: labelColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hasValue ? value! : (placeholder ?? ''),
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  color: secondary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (trailingExtra != null) ...[
              const SizedBox(width: 6),
              trailingExtra!,
            ],
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS list row with leading squircle icon, title and chevron.
class _AppleListRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;

  const _AppleListRow({
    this.icon,
    this.iconColor,
    this.iconBackground,
    required this.title,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive
        ? CupertinoColors.destructiveRed.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color:
                    iconBackground ??
                    CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor ?? titleColor),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                color: titleColor,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

/// Premium hero card for the "Testimony of the day".
/// Apple News / "Today" featured-card style: gradient + decorative giant quote glyph.
class _AppleTestimonyHero extends StatelessWidget {
  final Color tint;
  final String label;
  final String text;
  final String? author;
  final String? addedByName;
  final String? addedByAvatarUrl;
  final String? showFullLabel;
  final VoidCallback? onTap;
  const _AppleTestimonyHero({
    required this.tint,
    required this.label,
    required this.text,
    required this.author,
    this.addedByName,
    this.addedByAvatarUrl,
    this.showFullLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final displayName = addedByName?.isNotEmpty == true
        ? addedByName
        : (author?.isNotEmpty == true ? author : null);
    final hasAuthor = displayName != null;

    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withOpacity(isDark ? 0.30 : 0.18),
              tint.withOpacity(isDark ? 0.10 : 0.04),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: tint.withOpacity(isDark ? 0.18 : 0.10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Decorative giant quote glyph in top-right
              Positioned(
                top: -28,
                right: -10,
                child: IgnorePointer(
                  child: Text(
                    '\u201C',
                    style: TextStyle(
                      fontSize: 180,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: tint.withOpacity(isDark ? 0.16 : 0.12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: tint.withOpacity(0.35),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tint,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onTap != null)
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 16,
                            color: tint,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: labelColor,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showFullLabel != null && onTap != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoButton(
                          padding: const EdgeInsets.only(top: 8),
                          minimumSize: Size.zero,
                          onPressed: onTap,
                          child: Text(
                            showFullLabel!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: tint,
                            ),
                          ),
                        ),
                      ),
                    if (hasAuthor) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: tint.withOpacity(0.15),
                            foregroundImage:
                                addedByAvatarUrl != null &&
                                    addedByAvatarUrl!.isNotEmpty
                                ? NetworkImage(addedByAvatarUrl!)
                                : null,
                            child:
                                (addedByAvatarUrl == null ||
                                    addedByAvatarUrl!.isEmpty)
                                ? Icon(
                                    CupertinoIcons.person_fill,
                                    size: 13,
                                    color: tint,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: labelColor,
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
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Premium Apple-ID-style profile hero: gradient card, floating avatar, action chip.
class _AppleProfileHero extends StatelessWidget {
  final BackendUser user;
  final String? avatarUrl;
  final String? avatarLocalPath;
  final Color tint;
  final VoidCallback onEdit;
  final String editLabel;
  const _AppleProfileHero({
    required this.user,
    required this.avatarUrl,
    required this.avatarLocalPath,
    required this.tint,
    required this.onEdit,
    required this.editLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final ringColor = (isDark ? Colors.white : Colors.white).withOpacity(0.85);
    final shadowColor = tint.withOpacity(isDark ? 0.45 : 0.25);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = _iosSecondaryLabel(context);
    final avatarImage = _profileAvatarImage(avatarLocalPath, avatarUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withOpacity(isDark ? 0.32 : 0.20),
              tint.withOpacity(isDark ? 0.10 : 0.04),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              // Avatar with ring + shadow
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withOpacity(0.18),
                  border: Border.all(color: ringColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  image: avatarImage != null
                      ? DecorationImage(image: avatarImage, fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: avatarImage == null
                    ? Text(
                        user.initials,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: tint,
                          letterSpacing: -0.5,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                user.name.isEmpty ? '—' : user.name,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: labelColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: TextStyle(fontSize: 14, color: secondary),
              ),
              const SizedBox(height: 18),
              // Floating action chip
              _AppleActionChip(
                icon: CupertinoIcons.pencil,
                label: editLabel,
                onTap: onEdit,
                tint: tint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vibrant pill button used inside hero cards (glass + tint).
class _AppleActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tint;
  const _AppleActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.0 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tint,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Apple Health-style stat tile: icon, big number, label on card.
class _AppleStatCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  const _AppleStatCard({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: _iosCardBackground(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tint,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutreachStatsSheet extends StatefulWidget {
  final S tr;

  /// When non-null, the form is pre-filled for editing (direct set via PATCH).
  /// When null, the form is empty for adding (accumulate via POST /add).
  final OutreachStatEntry? existing;
  final Future<void> Function({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
    required int fathersLettersDistributed,
    required int healingsDeliverances,
    String? testimony,
  })
  onSave;

  const _OutreachStatsSheet({
    required this.tr,
    required this.existing,
    required this.onSave,
  });

  @override
  State<_OutreachStatsSheet> createState() => _OutreachStatsSheetState();
}

class _OutreachStatsSheetState extends State<_OutreachStatsSheet> {
  late final TextEditingController _gospels;
  late final TextEditingController _salvation;
  late final TextEditingController _scriptures;
  late final TextEditingController _fathersLetters;
  late final TextEditingController _healings;
  late final TextEditingController _testimony;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _gospels = TextEditingController(text: e != null ? '${e.gospelsTold}' : '');
    _salvation = TextEditingController(
      text: e != null ? '${e.salvationPrayedUnreachable}' : '',
    );
    _scriptures = TextEditingController(
      text: e != null ? '${e.scripturesDistributed}' : '',
    );
    _fathersLetters = TextEditingController(
      text: e != null ? '${e.fathersLettersDistributed}' : '',
    );
    _healings = TextEditingController(
      text: e != null ? '${e.healingsDeliverances}' : '',
    );
    _testimony = TextEditingController();
  }

  @override
  void dispose() {
    _gospels.dispose();
    _salvation.dispose();
    _scriptures.dispose();
    _fathersLetters.dispose();
    _healings.dispose();
    _testimony.dispose();
    super.dispose();
  }

  int _parse(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final testimonyText = _testimony.text.trim();
      await widget.onSave(
        gospelsTold: _parse(_gospels),
        salvationPrayedUnreachable: _parse(_salvation),
        scripturesDistributed: _parse(_scriptures),
        fathersLettersDistributed: _parse(_fathersLetters),
        healingsDeliverances: _parse(_healings),
        testimony: testimonyText.isEmpty ? null : testimonyText,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = widget.tr.outreachStatsError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final isEdit = widget.existing != null;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final height = MediaQuery.of(context).size.height * 0.72;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _iosBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (d) {
                if (d.primaryDelta != null && d.primaryDelta! > 10) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _iosSeparator(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? tr.editOutreachStats : tr.addOutreachStats,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CupertinoActivityIndicator()
                        : Text(
                            tr.save,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
            Divider(height: 0.5, color: _iosSeparator(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(0, 12, 0, viewInsets.bottom + 20),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AppleSection(
                        children: [
                          _AppleInputRow(
                            icon: CupertinoIcons.smiley,
                            iconBackground: const Color(0xFF34C759),
                            placeholder: tr.gospelsTold,
                            controller: _gospels,
                            keyboardType: TextInputType.number,
                          ),
                          _AppleInputRow(
                            icon: CupertinoIcons.heart,
                            iconBackground: const Color(0xFFFF3B30),
                            placeholder: tr.salvationPrayedUnreachable,
                            controller: _salvation,
                            keyboardType: TextInputType.number,
                          ),
                          _AppleInputRow(
                            icon: CupertinoIcons.book,
                            iconBackground: const Color(0xFFFF9500),
                            placeholder: tr.scripturesDistributed,
                            controller: _scriptures,
                            keyboardType: TextInputType.number,
                          ),
                          _AppleInputRow(
                            icon: CupertinoIcons.envelope_fill,
                            iconBackground: const Color(0xFF007AFF),
                            placeholder: tr.fathersLettersDistributed,
                            controller: _fathersLetters,
                            keyboardType: TextInputType.number,
                          ),
                          _AppleInputRow(
                            icon: CupertinoIcons.waveform_path_ecg,
                            iconBackground: const Color(0xFF5856D6),
                            placeholder: tr.healingsDeliverances,
                            controller: _healings,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                      if (!isEdit) ...[
                        const SizedBox(height: 20),
                        _AppleSection(
                          header: tr.testimonyLabel,
                          children: [
                            _AppleInputRow(
                              icon: CupertinoIcons.quote_bubble,
                              iconBackground: const Color(0xFF007AFF),
                              placeholder: tr.testimonyPlaceholder,
                              controller: _testimony,
                              minLines: 3,
                              maxLines: 6,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ],
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: CupertinoColors.destructiveRed.resolveFrom(
                                context,
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty/error state for unauthenticated profile.
class _AppleProfileEmpty extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final bool destructive;
  const _AppleProfileEmpty({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.14),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 44, color: iconColor),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 15,
                  color: _iosSecondaryLabel(context),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: destructive
                  ? CupertinoColors.destructiveRed.resolveFrom(context)
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS-style large title block (sits at top of scroll view).
class _AppleLargeTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSettings;
  const _AppleLargeTitle({required this.title, this.subtitle, this.onSettings});

  @override
  Widget build(BuildContext context) {
    final secondary = _iosSecondaryLabel(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              if (onSettings != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 32,
                  onPressed: onSettings,
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 15, color: secondary)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
