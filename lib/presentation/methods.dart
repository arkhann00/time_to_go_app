part of '../main.dart';

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
