import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'user_profile_cache.dart';

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

class OutreachTestimony {
  final int id;
  final String text;
  const OutreachTestimony({required this.id, required this.text});

  factory OutreachTestimony.fromMap(Map<String, dynamic> m) =>
      OutreachTestimony(
        id: (m['id'] as num?)?.toInt() ?? 0,
        text: (m['text'] as String? ?? '').trim(),
      );
}

class OutreachStatEntry {
  final int id;
  final int userId;
  final int gospelsTold;
  final int salvationPrayedUnreachable;
  final int scripturesDistributed;
  final int healingsDeliverances;
  final List<OutreachTestimony> testimonies;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userName;
  final String? userAvatarUrl;

  OutreachStatEntry({
    required this.id,
    required this.userId,
    required this.gospelsTold,
    required this.salvationPrayedUnreachable,
    required this.scripturesDistributed,
    required this.healingsDeliverances,
    required this.createdAt,
    required this.updatedAt,
    this.testimonies = const [],
    this.userName = '',
    this.userAvatarUrl,
  });

  factory OutreachStatEntry.fromMap(Map<String, dynamic> m) {
    final user = m['user'] as Map<String, dynamic>? ?? {};
    return OutreachStatEntry(
      id: (m['id'] as num?)?.toInt() ?? 0,
      userId: (m['user_id'] as num?)?.toInt() ?? 0,
      gospelsTold: (m['gospels_told'] as num?)?.toInt() ?? 0,
      salvationPrayedUnreachable:
          (m['salvation_prayed_unreachable'] as num?)?.toInt() ?? 0,
      scripturesDistributed:
          (m['scriptures_distributed'] as num?)?.toInt() ?? 0,
      healingsDeliverances: (m['healings_deliverances'] as num?)?.toInt() ?? 0,
      testimonies:
          (m['testimonies'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(OutreachTestimony.fromMap)
              .where((t) => t.text.isNotEmpty)
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.now(),
      userName: (user['name'] as String? ?? '').trim(),
      userAvatarUrl: user['avatar_url'] as String?,
    );
  }
}

class SummaryStats {
  final int totalHeardGospel;
  final int heardGospelNoContact;
  final int heardGospelHasContact;
  final int scripturesDistributed;
  final int healingsDeliverances;

  const SummaryStats({
    this.totalHeardGospel = 0,
    this.heardGospelNoContact = 0,
    this.heardGospelHasContact = 0,
    this.scripturesDistributed = 0,
    this.healingsDeliverances = 0,
  });

  factory SummaryStats.fromMap(Map<String, dynamic> m) => SummaryStats(
    totalHeardGospel: (m['total_heard_gospel'] as num?)?.toInt() ?? 0,
    heardGospelNoContact: (m['heard_gospel_no_contact'] as num?)?.toInt() ?? 0,
    heardGospelHasContact:
        (m['heard_gospel_has_contact'] as num?)?.toInt() ?? 0,
    scripturesDistributed: (m['scriptures_distributed'] as num?)?.toInt() ?? 0,
    healingsDeliverances: (m['healings_deliverances'] as num?)?.toInt() ?? 0,
  );
}

/// iOS form row: leading squircle icon + Cupertino-style text field.
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
  final VoidCallback? onTap;
  const _AppleTestimonyHero({
    required this.tint,
    required this.label,
    required this.text,
    required this.author,
    this.addedByName,
    this.addedByAvatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = _iosSecondaryLabel(context);
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
                              displayName!,
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
    defaultValue: 'http://138.16.161.26:8000',
  );
  static const _apiAccessToken = String.fromEnvironment('API_ACCESS_TOKEN');

  late final BackendApi _backendApi;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppLanguage _language = AppLanguage.ru;
  String? _accessToken;
  bool _continueOffline = true;
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

    if (_isApple) {
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
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _tab,
                      children: {
                        0: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(tr.signIn),
                        ),
                        1: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(tr.signUp),
                        ),
                      },
                      onValueChanged: (v) {
                        if (_busy) return;
                        setState(() {
                          _tab = v ?? 0;
                          _error = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_tab == 1) ...[
                    CupertinoTextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_busy,
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
                          color: CupertinoColors.separator.resolveFrom(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  CupertinoTextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    placeholder: tr.authEmail,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        CupertinoIcons.at,
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
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    placeholder: tr.authPassword,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        CupertinoIcons.lock,
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
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: CupertinoColors.destructiveRed.resolveFrom(
                          context,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _busy ? null : _submit,
                      borderRadius: BorderRadius.circular(12),
                      child: _busy
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : Text(_tab == 0 ? tr.signIn : tr.signUp),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: _busy ? null : widget.onContinueOffline,
                    child: Text(
                      tr.continueOffline,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
    required int healingsDeliverances,
    String? testimony,
  }) async {
    final result = await _backendApi.addOutreachStatistics(
      gospelsTold: gospelsTold,
      salvationPrayedUnreachable: salvationPrayedUnreachable,
      scripturesDistributed: scripturesDistributed,
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
    required int healingsDeliverances,
  }) async {
    final result = await _backendApi.patchOutreachStatisticsMe(
      gospelsTold: gospelsTold,
      salvationPrayedUnreachable: salvationPrayedUnreachable,
      scripturesDistributed: scripturesDistributed,
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
                required int healingsDeliverances,
                String? testimony,
              }) => _addOutreachStats(
                gospelsTold: gospelsTold,
                salvationPrayedUnreachable: salvationPrayedUnreachable,
                scripturesDistributed: scripturesDistributed,
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
              required int healingsDeliverances,
              String? testimony,
            }) => _addOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
              healingsDeliverances: healingsDeliverances,
              testimony: testimony,
            ),
        onEditOutreachStats:
            ({
              required int gospelsTold,
              required int salvationPrayedUnreachable,
              required int scripturesDistributed,
              required int healingsDeliverances,
            }) => _editOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
              healingsDeliverances: healingsDeliverances,
            ),
        onResetOutreachStats: _resetOutreachStats,
        onDeleteTestimony: widget.isAuthenticated
            ? _deleteOutreachTestimony
            : null,
        onLogout: widget.onLogout,
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
              text: latest?.text ?? tr.noLatestTestimonies,
              author: latest?.author,
              addedByName: latest?.addedByName,
              addedByAvatarUrl: latest?.addedByAvatarUrl,
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
                            '”${latest?.text ?? tr.noLatestTestimonies}”',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.38,
                              fontWeight: FontWeight.w500,
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
              required int healingsDeliverances,
              String? testimony,
            }) => onSave(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
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
        // ── Hero stat: total heard gospel ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tint, tint.withOpacity(0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
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
                      CupertinoIcons.person_3_fill,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr.totalHeardGospel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _fmt(summary.totalHeardGospel),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Contact breakdown row ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: CupertinoIcons.phone_arrow_down_left,
                color: const Color(0xFFFF9500),
                value: _fmt(summary.heardGospelNoContact),
                label: tr.heardGospelNoContact,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(
                context,
                icon: CupertinoIcons.phone_fill,
                color: const Color(0xFF34C759),
                value: _fmt(summary.heardGospelHasContact),
                label: tr.heardGospelHasContact,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Scriptures + Healings row ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: CupertinoIcons.book_fill,
                color: const Color(0xFFFF3B30),
                value: _fmt(summary.scripturesDistributed),
                label: tr.scripturesDistributed,
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
        // ── Hero stat ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
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
                      Icons.groups_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr.totalHeardGospel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _fmt(summary.totalHeardGospel),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Contact breakdown ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: Icons.phone_missed_rounded,
                color: const Color(0xFFFF9500),
                value: _fmt(summary.heardGospelNoContact),
                label: tr.heardGospelNoContact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _miniCard(
                context,
                icon: Icons.phone_in_talk_rounded,
                color: const Color(0xFF34C759),
                value: _fmt(summary.heardGospelHasContact),
                label: tr.heardGospelHasContact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Scriptures + Healings ─────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _miniCard(
                context,
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFFF3B30),
                value: _fmt(summary.scripturesDistributed),
                label: tr.scripturesDistributed,
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

class _ZoomableMethodAssetImage extends StatefulWidget {
  final String asset;
  final String semanticLabel;
  final String? imageMissing;
  final double? width;
  final BoxFit fit;
  final bool immersive;
  final VoidCallback? onOpenFullscreen;
  final ValueChanged<bool>? onZoomChanged;
  final void Function(ScaleUpdateDetails)? onInteractionUpdate;
  final void Function(ScaleEndDetails)? onInteractionEnd;

  const _ZoomableMethodAssetImage({
    required this.asset,
    required this.semanticLabel,
    this.imageMissing,
    this.width,
    this.fit = BoxFit.fitWidth,
    this.immersive = false,
    this.onOpenFullscreen,
    this.onZoomChanged,
    this.onInteractionUpdate,
    this.onInteractionEnd,
  });

  @override
  State<_ZoomableMethodAssetImage> createState() =>
      _ZoomableMethodAssetImageState();
}

class _ZoomableMethodAssetImageState extends State<_ZoomableMethodAssetImage>
    with SingleTickerProviderStateMixin {
  static const _doubleTapScale = 2.75;
  static const _zoomEpsilon = 0.02;

  final _transformController = TransformationController();
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _transformController.addListener(_onTransformChanged);
    _zoomAnimationController.addListener(_onZoomAnimationTick);
    _zoomAnimationController.addStatusListener(_onZoomAnimationStatus);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _zoomAnimationController.removeListener(_onZoomAnimationTick);
    _transformController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (_zoomAnimationController.isAnimating) return;
    final next = _transformController.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() < _zoomEpsilon) return;
    final wasZoomed = _isZoomed;
    setState(() => _scale = next);
    if (_isZoomed != wasZoomed) widget.onZoomChanged?.call(_isZoomed);
  }

  void _onZoomAnimationTick() {
    final animation = _zoomAnimation;
    if (animation == null) return;
    _transformController.value = animation.value;
  }

  bool get _isZoomed => _scale > 1 + _zoomEpsilon;

  void _resetZoom() {
    if (!_isZoomed) return;
    _animateTo(Matrix4.identity());
  }

  void _onZoomAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final wasZoomed = _isZoomed;
    setState(() => _scale = _transformController.value.getMaxScaleOnAxis());
    if (_isZoomed != wasZoomed) widget.onZoomChanged?.call(_isZoomed);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformController.value.clone(),
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _zoomAnimationController.forward(from: 0);
  }

  void _handleDoubleTap(TapDownDetails details) {
    final target = _isZoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translate(details.localPosition.dx, details.localPosition.dy)
            ..scale(_doubleTapScale)
            ..translate(-details.localPosition.dx, -details.localPosition.dy));
    _animateTo(target);
  }

  void _handleTap() {
    if (_isZoomed) {
      _resetZoom();
      return;
    }
    widget.onOpenFullscreen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final errorStyle = widget.immersive
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white70)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

    final image = Image.asset(
      widget.asset,
      semanticLabel: widget.semanticLabel,
      width: widget.width,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Padding(
          padding: EdgeInsets.all(widget.immersive ? 28 : 24),
          child: Text(
            widget.imageMissing ?? '',
            textAlign: TextAlign.center,
            style: errorStyle,
          ),
        ),
      ),
    );

    final viewer = InteractiveViewer(
      transformationController: _transformController,
      minScale: 1,
      maxScale: 5,
      panEnabled: _isZoomed,
      scaleEnabled: true,
      clipBehavior: Clip.none,
      boundaryMargin: widget.immersive
          ? const EdgeInsets.all(48)
          : const EdgeInsets.all(20),
      onInteractionUpdate: widget.onInteractionUpdate,
      onInteractionEnd: widget.onInteractionEnd,
      child: image,
    );

    final zoomable = GestureDetector(
      onTap: widget.immersive || widget.onOpenFullscreen != null
          ? _handleTap
          : null,
      onDoubleTapDown: _handleDoubleTap,
      behavior: HitTestBehavior.deferToChild,
      child: viewer,
    );

    if (!widget.immersive) return zoomable;

    final size = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width,
                  maxHeight: size.height,
                ),
                child: zoomable,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FullscreenEvangelAsset extends StatefulWidget {
  final String asset;
  final String semanticLabel;
  final String imageMissing;

  const _FullscreenEvangelAsset({
    required this.asset,
    required this.semanticLabel,
    required this.imageMissing,
  });

  @override
  State<_FullscreenEvangelAsset> createState() =>
      _FullscreenEvangelAssetState();
}

class _FullscreenEvangelAssetState extends State<_FullscreenEvangelAsset>
    with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  double _bgOpacity = 1.0;
  bool _isZoomed = false;
  late final AnimationController _snapCtrl;

  static const _dismissDist = 90.0;
  static const _dismissVelocity = 450.0;
  static const _opacityBase = 200.0;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onZoomChanged(bool zoomed) {
    if (_isZoomed == zoomed) return;
    setState(() {
      _isZoomed = zoomed;
      if (!zoomed) {
        _drag = Offset.zero;
        _bgOpacity = 1.0;
      }
    });
  }

  void _onInteractionUpdate(ScaleUpdateDetails d) {
    // only single-finger pan when not zoomed
    if (_isZoomed || d.pointerCount != 1) return;
    _snapCtrl.stop();
    setState(() {
      _drag += d.focalPointDelta;
      _bgOpacity = (1.0 - _drag.distance / _opacityBase).clamp(0.1, 1.0);
    });
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    if (_isZoomed) return;
    final speed = d.velocity.pixelsPerSecond.distance;
    if (speed > _dismissVelocity || _drag.distance > _dismissDist) {
      Navigator.of(context).pop();
      return;
    }
    final startDrag = _drag;
    final anim = Tween<Offset>(
      begin: startDrag,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic));
    anim.addListener(() {
      if (!mounted) return;
      setState(() {
        _drag = anim.value;
        _bgOpacity = (1.0 - _drag.distance / _opacityBase).clamp(0.1, 1.0);
      });
    });
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: _bgOpacity),
      child: Transform.translate(
        offset: _drag,
        child: SafeArea(
          child: _ZoomableMethodAssetImage(
            asset: widget.asset,
            semanticLabel: widget.semanticLabel,
            imageMissing: widget.imageMissing,
            fit: BoxFit.contain,
            immersive: true,
            onZoomChanged: _onZoomChanged,
            onInteractionUpdate: _onInteractionUpdate,
            onInteractionEnd: _onInteractionEnd,
          ),
        ),
      ),
    );
  }
}

class _FourSignsCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final ThemeData theme;

  const _FourSignsCard({
    required this.number,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '$number. $title',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.52)),
        ],
      ),
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

  static const _fourSignsDarkAsset = 'assets/four_signs_dark.PNG';
  static const _fourSignsLightAsset = 'assets/four_signs_light.PNG';
  static const _jesusDoor1 = 'assets/jesus_on_the_door_1.PNG';
  static const _jesusDoor2 = 'assets/jesus_on_the_door_2.PNG';

  void _showFourSignsDetails(BuildContext context) {
    final tr = widget.tr;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _isApple
                    ? _iosCardBackground(context)
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Icon(
                          _isApple
                              ? CupertinoIcons.info_circle_fill
                              : Icons.info_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr.methodFourSignsTab,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            _isApple
                                ? CupertinoIcons.xmark_circle_fill
                                : Icons.cancel_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  // Scrollable content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      children: [
                        // Sign 1 — Love
                        _FourSignsCard(
                          number: '1',
                          icon: _isApple
                              ? CupertinoIcons.heart_fill
                              : Icons.favorite_rounded,
                          color: const Color(0xFFFF3B30),
                          title: tr.lang == AppLanguage.ru ? 'Любовь' : 'Love',
                          body: tr.lang == AppLanguage.ru
                              ? 'Бог сотворил весь мир, в том числе и человека с вечной душой! Он любит тебя и всех людей. Он хочет, чтобы ты узнал Его, принял Его любовь, и чтобы твоя жизнь обрела смысл.\n\n📖 «Ибо так возлюбил Бог мир, что отдал Сына Своего Единородного...» (Ин. 3:16)'
                              : 'God created the whole world, including man with an eternal soul! He loves you and all people. He wants you to know Him, receive His love, and find meaning in your life.\n\n📖 "For God so loved the world that He gave His one and only Son..." (John 3:16)',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        // Sign 2 — Separation
                        _FourSignsCard(
                          number: '2',
                          icon: _isApple
                              ? CupertinoIcons.divide
                              : Icons.remove_circle_outline_rounded,
                          color: const Color(0xFFFF9500),
                          title: tr.lang == AppLanguage.ru
                              ? 'Разделение'
                              : 'Separation',
                          body: tr.lang == AppLanguage.ru
                              ? 'Человек отделён от Бога из-за греха, поэтому не может почувствовать Его любовь. За грех будет справедливое наказание — смерть и вечное отлучение от Бога.\n\n📖 «Потому что возмездие за грех — смерть...» (Рим. 6:23)'
                              : 'Man is separated from God because of sin, so he cannot feel His love. Sin brings a just punishment — death and eternal separation from God.\n\n📖 "For the wages of sin is death..." (Romans 6:23)',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        // Sign 3 — Jesus
                        _FourSignsCard(
                          number: '3',
                          icon: _isApple
                              ? CupertinoIcons.add
                              : Icons.add_circle_outline_rounded,
                          color: const Color(0xFF34C759),
                          title: tr.lang == AppLanguage.ru ? 'Иисус' : 'Jesus',
                          body: tr.lang == AppLanguage.ru
                              ? 'Но Бог предложил решение — Иисус Христос, Божий Сын. Благодаря Ему мы можем восстановить отношения с Богом, почувствовать Его любовь и обрести полноценную жизнь на земле и вечную жизнь с Ним.\n\n📖 «Иисус сказал ему: Я есмь путь и истина и жизнь...» (Ин. 14:6)'
                              : 'But God offered a solution — Jesus Christ, the Son of God. Through Him we can restore our relationship with God, experience His love, and gain abundant life on earth and eternal life with Him.\n\n📖 "Jesus answered, I am the way and the truth and the life..." (John 14:6)',
                          theme: theme,
                        ),
                        const SizedBox(height: 12),
                        // Sign 4 — Decision
                        _FourSignsCard(
                          number: '4',
                          icon: _isApple
                              ? CupertinoIcons.question_circle_fill
                              : Icons.help_rounded,
                          color: const Color(0xFF007AFF),
                          title: tr.lang == AppLanguage.ru
                              ? 'Решение'
                              : 'Decision',
                          body: tr.lang == AppLanguage.ru
                              ? 'Тебе нужно сделать личный шаг веры и принять Иисуса Христа как спасителя и Господа. Он предлагает тебе радостную жизнь, полную Его любви на земле и вечную жизнь вместе с Богом.\n\n📖 «А тем, которые приняли Его, верующим во имя Его, дал власть быть чадами Божиими...» (Ин. 1:12)'
                              : 'You need to take a personal step of faith and receive Jesus Christ as Savior and Lord. He offers you a joyful life full of His love on earth and eternal life with God.\n\n📖 "Yet to all who received Him, to those who believed in His name, He gave the right to become children of God..." (John 1:12)',
                          theme: theme,
                        ),
                        const SizedBox(height: 24),
                        // Prayer block
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(
                                0.25,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Icon(
                                  //   _isApple
                                  //       ? CupertinoIcons.hands_sparkles_fill
                                  //       : Icons.volunteer_activism_rounded,
                                  //   color: theme.colorScheme.primary,
                                  //   size: 18,
                                  // ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr.lang == AppLanguage.ru
                                        ? 'Молитва принятия'
                                        : 'Prayer of Acceptance',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tr.lang == AppLanguage.ru
                                    ? '«Господи Иисус, я понимаю, что я грешен и нуждаюсь в Твоём прощении. Верю, что Ты умер за мои грехи и воскрес. Я хочу отвернуться от грехов своих. Прошу Тебя войти в мою жизнь и стать моим Спасителем и Господом. Аминь.»'
                                    : '"Lord Jesus, I know I am a sinner and need Your forgiveness. I believe You died for my sins and rose again. I want to turn from my sins. I now invite You to come into my life as my Savior and Lord. Amen."',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  height: 1.55,
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
            );
          },
        );
      },
    );
  }

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
    final isDark = theme.brightness == Brightness.dark;
    final fourSignsAsset = isDark ? _fourSignsDarkAsset : _fourSignsLightAsset;

    Widget methodImage(String asset, String semanticLabel) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              child: _ZoomableMethodAssetImage(
                asset: asset,
                semanticLabel: semanticLabel,
                imageMissing: tr.imageMissing,
                width: constraints.maxWidth,
                fit: BoxFit.fitWidth,
                onOpenFullscreen: () =>
                    _openFullscreen(context, asset, semanticLabel),
              ),
            ),
          );
        },
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, _isApple ? 110 : 32),
      children: [
        _PageHeader(
          title: tr.methodsPageTitle,
          subtitle: tr.methodsPageSub,
          onSettings: widget.onSettings,
        ),
        const SizedBox(height: 16),
        if (_isApple)
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _methodIndex,
              children: {
                0: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tr.methodFourSignsTab),
                ),
                1: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tr.methodJesusDoorTab),
                ),
              },
              onValueChanged: (v) {
                if (v != null) setState(() => _methodIndex = v);
              },
            ),
          )
        else
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
                    Text(
                      tr.methodFourSignsDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    methodImage(fourSignsAsset, tr.methodFourSignsTab),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: _isApple
                          ? CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              color: theme.colorScheme.primary.withOpacity(
                                0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: () => _showFourSignsDetails(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.info_circle,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr.lang == AppLanguage.ru
                                        ? 'Подробное пояснение'
                                        : 'Detailed explanation',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.5,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _showFourSignsDetails(context),
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                tr.lang == AppLanguage.ru
                                    ? 'Подробное пояснение'
                                    : 'Detailed explanation',
                              ),
                            ),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('m1'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr.methodJesusDoorDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
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
  final VoidCallback onSettings;
  final OutreachStatEntry? myStats;
  final bool myStatsLoading;
  final Future<void> Function({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
    required int healingsDeliverances,
    String? testimony,
  })
  onAddOutreachStats;
  final Future<void> Function({
    required int gospelsTold,
    required int salvationPrayedUnreachable,
    required int scripturesDistributed,
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
              required int healingsDeliverances,
              String? testimony,
            }) => onAddOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
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
              required int healingsDeliverances,
              String? testimony,
            }) => onEditOutreachStats(
              gospelsTold: gospelsTold,
              salvationPrayedUnreachable: salvationPrayedUnreachable,
              scripturesDistributed: scripturesDistributed,
              healingsDeliverances: healingsDeliverances,
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
              iconBackground: CupertinoColors.destructiveRed.resolveFrom(
                context,
              ),
              iconColor: CupertinoColors.white,
              title: tr.signOut,
              destructive: true,
              onTap: () => _confirmLogout(context),
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
                                    myStats!.testimonies[i].id)
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
    if (_isApple) {
      DateTime tempDate = _date;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: Text(S(widget.language).cancel),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: Text(S(widget.language).done),
                      onPressed: () {
                        setState(() => _date = tempDate);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _date,
                  minimumDate: DateTime(2020),
                  maximumDate: DateTime(2040),
                  onDateTimeChanged: (d) => tempDate = d,
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
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

  void _submitForm(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      NewBeliever(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        telegram: _normalizeTelegramForStorage(_telegram.text),
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
  }

  Future<void> _pickStage() async {
    final tr = S(widget.language);
    final selected = await showCupertinoModalPopup<BelieverStage>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr.stage),
        actions: BelieverStage.values
            .map(
              (s) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dot(stage: s, size: 10),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        stageFull(s, widget.language),
                        style: TextStyle(
                          fontWeight: s == _stage
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
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
    if (selected != null) setState(() => _stage = selected);
  }

  Future<void> _pickMethod() async {
    final tr = S(widget.language);
    final selected = await showCupertinoModalPopup<EvangelismMethod>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(tr.evangelismMethod),
        actions: EvangelismMethod.values
            .map(
              (m) => CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(m),
                child: Text(
                  evangelismMethodLabel(m, tr),
                  style: TextStyle(
                    fontWeight: m == _method
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
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
    if (selected != null) setState(() => _method = selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_isApple) return _buildApple(context);
    return _buildMaterial(context);
  }

  Widget _buildApple(BuildContext context) {
    final tr = S(widget.language);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final hasLocation = _location != null;
    final locationValue = hasLocation
        ? (_placeName?.trim().isNotEmpty == true
              ? _placeName!.trim()
              : '${_location!.latitude.toStringAsFixed(4)}, '
                    '${_location!.longitude.toStringAsFixed(4)}')
        : null;

    return Container(
      height: mq.size.height * 0.94,
      decoration: BoxDecoration(
        color: _iosBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
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
                    tr.add,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  onPressed: () => _submitForm(context),
                  child: Text(
                    tr.save,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  4,
                  0,
                  mq.viewInsets.bottom + 32,
                ),
                children: [
                  _AppleSection(
                    header: tr.name,
                    dividerIndent: 58,
                    children: [
                      _AppleInputRow(
                        icon: CupertinoIcons.person_alt,
                        iconBackground: const Color(0xFF34C759),
                        placeholder: tr.name,
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? tr.nameReq : null,
                      ),
                      _AppleInputRow(
                        icon: CupertinoIcons.at,
                        iconBackground: const Color(0xFF0A84FF),
                        placeholder: tr.telegramHint,
                        controller: _telegram,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_@./:?=&-]'),
                          ),
                        ],
                        validator: (_) => _validateTelegram(tr),
                      ),
                      _AppleInputRow(
                        icon: CupertinoIcons.phone_fill,
                        iconBackground: const Color(0xFFFF9F0A),
                        placeholder: tr.phoneHint,
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+()\-\s]'),
                          ),
                          _PhoneInputFormatter(),
                        ],
                        validator: (_) => _validatePhone(tr),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.stage,
                    children: [
                      _AppleTapRow(
                        icon: CupertinoIcons.calendar,
                        iconBackground: const Color(0xFFFF3B30),
                        title: tr.date,
                        value: fmtDate(_date, widget.language),
                        onTap: _pickDate,
                      ),
                      _AppleTapRow(
                        icon: CupertinoIcons.flag_fill,
                        iconBackground: stageColor(_stage),
                        title: tr.stage,
                        value: stageFull(_stage, widget.language),
                        onTap: _pickStage,
                      ),
                      _AppleTapRow(
                        icon: CupertinoIcons.book_fill,
                        iconBackground: const Color(0xFFAF52DE),
                        title: tr.evangelismMethod,
                        value: evangelismMethodLabel(_method, tr),
                        onTap: _pickMethod,
                      ),
                      if (_method == EvangelismMethod.custom)
                        _AppleInputRow(
                          icon: CupertinoIcons.pencil,
                          iconBackground: const Color(0xFF8E8E93),
                          placeholder: tr.customMethodHint,
                          controller: _customMethod,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (value) {
                            if (_method != EvangelismMethod.custom) return null;
                            if (value == null || value.trim().isEmpty) {
                              return tr.customMethodReq;
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.testimony,
                    footer: tr.testimonyHint,
                    children: [
                      _AppleInputRow(
                        placeholder: tr.testimony,
                        controller: _testimony,
                        minLines: 3,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.note,
                    children: [
                      _AppleInputRow(
                        placeholder: tr.noteHint,
                        controller: _note,
                        minLines: 3,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AppleSection(
                    header: tr.location,
                    children: [
                      _AppleTapRow(
                        icon: CupertinoIcons.location_fill,
                        iconBackground: const Color(0xFFFF3B30),
                        title: tr.location,
                        value: locationValue,
                        placeholder: tr.tapToPlace,
                        onTap: _pickLocation,
                        trailingExtra: hasLocation
                            ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _clearLocation,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 4,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    size: 18,
                                    color: CupertinoColors.systemGrey3
                                        .resolveFrom(context),
                                  ),
                                ),
                              )
                            : null,
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

  Widget _buildMaterial(BuildContext context) {
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
            margin: const EdgeInsets.only(top: 8, bottom: 4),
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
                        onPressed: () => _submitForm(context),
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
                _isApple
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 28,
                          color: CupertinoColors.systemGrey3,
                        ),
                      )
                    : IconButton(
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
                  if (_isApple)
                    CupertinoTextField(
                      controller: _placeCtrl,
                      placeholder: tr.placeName,
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(
                          CupertinoIcons.location,
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
                          color: CupertinoColors.separator.resolveFrom(context),
                        ),
                      ),
                    )
                  else
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
                        child: _isApple
                            ? CupertinoButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(tr.cancel),
                              )
                            : OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(tr.cancel),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isApple
                            ? CupertinoButton.filled(
                                borderRadius: BorderRadius.circular(12),
                                onPressed: _selected == null
                                    ? null
                                    : () {
                                        final placeText = _placeCtrl.text
                                            .trim();
                                        Navigator.of(context).pop(
                                          PickedLocation(
                                            latLng: _selected!,
                                            place: placeText.isEmpty
                                                ? null
                                                : placeText,
                                          ),
                                        );
                                      },
                                child: Text(tr.done),
                              )
                            : FilledButton.icon(
                                onPressed: _selected == null
                                    ? null
                                    : () {
                                        final placeText = _placeCtrl.text
                                            .trim();
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

class LatestTestimony {
  final String text;
  final String? author;
  final String? addedByName;
  final String? addedByAvatarUrl;
  final DateTime createdAt;
  const LatestTestimony({
    required this.text,
    required this.author,
    required this.createdAt,
    this.addedByName,
    this.addedByAvatarUrl,
  });
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar_url': avatarUrl,
    'about': about,
  };
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
  String get statisticsHeader => _ru ? 'Статистика' : 'Statistics';
  String get personalStatsHeader =>
      _ru ? 'Личная статистика' : 'Personal stats';
  String get appearance => _ru ? 'Оформление' : 'Appearance';
  String get accountSection => _ru ? 'Аккаунт' : 'Account';
  String get dashSub => _ru
      ? 'Учёт новых верующих и этапов духовного роста'
      : 'Track new believers and their growth';
  String get homeWitnessSub => _ru
      ? 'Последнее свидетельство и ключевые цифры'
      : 'Latest testimony and key numbers';
  String get latestTestimony =>
      _ru ? 'Последнее свидетельство' : 'Latest testimony';
  String get latestTestimoniesTitle =>
      _ru ? 'Последние свидетельства' : 'Latest testimonies';
  String get noLatestTestimonies =>
      _ru ? 'Пока нет свидетельств.' : 'No testimonies yet.';
  String get back => _ru ? 'Назад' : 'Back';
  String get heardGospelCountLabel => _ru
      ? 'Всего человек спасение Евангелие'
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
  String get methodFourSignsDesc => _ru
      ? '«Четыре символа» — это отличный способ донести Евангелие простым и понятным способом. Вы можете начать разговор, задав человеку вопрос: «Вы когда-нибудь слышали историю о четырёх символах?» Затем вы показываете ему эти четыре символа и объясняете Евангелие, опираясь на них.'
      : '"The Four" is a great way to share the Gospel in a simple and clear way. You can start a conversation by asking: "Have you ever heard the story of the four symbols?" Then you show them these four symbols and explain the Gospel based on them.';
  String get methodJesusDoorTab => _ru ? 'Иисус у двери' : 'Jesus at the door';
  String get methodJesusDoorDesc => _ru
      ? '«Иисус у двери» — это очень креативный метод благовестия, представляющий собой полностью прописанный диалог. Он работает только в том случае, если вы уделите время и усилия, чтобы выучить весь разговор слово в слово. Используйте изображение Иисуса, стучащего в дверь, и пройдите через весь этот диалог.'
      : '"Jesus at the Door" is a very creative evangelism method that consists of a fully scripted dialogue. It only works if you take the time and effort to learn the entire conversation word for word. Use the image of Jesus knocking at the door and go through this entire dialogue.';
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

  // Outreach statistics
  String get outreachStatsHeader =>
      _ru ? 'Статистика аутрича' : 'Outreach stats';
  String get gospelsTold => _ru ? 'Поделились Евангелием' : 'Gospels told';
  String get salvationPrayedUnreachable =>
      _ru ? 'Помолились молитвой покаяния' : 'Prayed, unreachable';
  String get scripturesDistributed =>
      _ru ? 'Роздано Евангелий от Иоана' : 'Gospels of John distributed';
  String get healingsDeliverances =>
      _ru ? 'Исцелений / освобождений' : 'Healings & deliverances';
  String get addOutreachStats => _ru ? 'Добавить аутрич' : 'Add outreach';
  String get editOutreachStats => _ru ? 'Редактировать' : 'Edit';
  String get testimonyLabel => _ru ? 'Свидетельство' : 'Testimony';
  String get testimonyPlaceholder =>
      _ru ? 'Напишите ваше свидетельство...' : 'Write your testimony...';
  String get deleteTestimony =>
      _ru ? 'Удалить свидетельство' : 'Delete testimony';
  String get outreachStatsEmpty =>
      _ru ? 'Нет статистики аутрича' : 'No outreach stats yet';
  String get outreachStatsSaved => _ru ? 'Статистика сохранена' : 'Stats saved';
  String get outreachStatsError =>
      _ru ? 'Не удалось сохранить' : 'Could not save stats';
  String get noStatsYet => _ru ? 'Нет данных аутрича' : 'No outreach data yet';
  String get resetStats => _ru ? 'Сбросить' : 'Reset';
  String get resetStatsTitle => _ru ? 'Сбросить статистику?' : 'Reset stats?';
  String get resetStatsBody => _ru
      ? 'Все счётчики будут обнулены. Это действие нельзя отменить.'
      : 'All counters will be set to zero. This cannot be undone.';
  // Summary stats labels
  String get generalStats => _ru ? 'Общая' : 'General';
  String get personalStats => _ru ? 'Личная' : 'Personal';
  String get totalHeardGospel =>
      _ru ? 'Всего спасение евангелие' : 'Total heard the Gospel';
  String get heardGospelNoContact =>
      _ru ? 'Спаслось, нет контакта' : 'Heard, no contact';
  String get heardGospelHasContact =>
      _ru ? 'Спаслось, есть контакт' : 'Heard, has contact';
  String get personalStatsUnavailable => _ru
      ? 'Войдите в аккаунт, чтобы видеть личную статистику'
      : 'Sign in to view personal statistics';
}
