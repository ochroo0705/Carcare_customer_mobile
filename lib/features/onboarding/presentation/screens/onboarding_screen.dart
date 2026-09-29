import 'dart:math' as math;

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/analytics/analytics_service.dart';
import 'package:carcare_customer_mobile/core/permissions/notification_permission_service.dart';
import 'package:flutter/material.dart';

/// First-run onboarding, three pages: welcome (with an app preview) → how it
/// works (find / book / track) → ready (notification ask + get-started with a
/// skippable soft-login). Shown once; [onFinish] fires when the user finishes —
/// `login: true` means route them to sign-in, `false` means drop them into the
/// app to browse.
///
/// Location is deliberately not asked here: iOS shows its prompt only once, so
/// a cold "no" during onboarding is effectively permanent. The discovery map
/// asks in context instead (locate-me button / location banner).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onFinish,
    this.notificationService =
        const PermissionHandlerNotificationPermissionService(),
    this.analytics = const NoopAnalyticsService(),
    super.key,
  });

  final void Function({required bool login}) onFinish;
  final NotificationPermissionService notificationService;

  /// Funnel events: `onboarding_page_view`, `onboarding_skip`,
  /// `onboarding_notification_result`, `onboarding_finish`.
  final AnalyticsService analytics;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  static const _lastIndex = 2; // welcome, how it works, ready
  static const _pageNames = ['welcome', 'how_it_works', 'ready'];

  @override
  void initState() {
    super.initState();
    _logPageView(0);
  }

  void _logPageView(int page) => widget.analytics.logEvent(
    'onboarding_page_view',
    {'page': page, 'page_name': _pageNames[page]},
  );

  void _finish({required bool login}) {
    widget.analytics.logEvent('onboarding_finish', {
      'method': login ? 'login' : 'browse',
      'page_name': _pageNames[_index],
    });
    widget.onFinish(login: login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  // Skip jumps past the info pages but never past the last page — its
  // notification ask is what booking confirmations depend on.
  void _skip() {
    widget.analytics.logEvent('onboarding_skip', {
      'page_name': _pageNames[_index],
    });
    _animateTo(_lastIndex);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onLast = _index == _lastIndex;
    // System back steps to the previous page instead of leaving the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _animateTo(_index - 1);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Skip (hidden on the last page, which has its own CTAs).
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: onLast ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: onLast ? null : _skip,
                      child: const Text('Алгасах'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    _logPageView(i);
                  },
                  children: [
                    _WelcomePage(
                      active: _index == 0,
                      onLogin: () => _finish(login: true),
                    ),
                    _HowItWorksPage(active: _index == 1),
                    _ReadyPage(
                      active: _index == 2,
                      notificationService: widget.notificationService,
                      analytics: widget.analytics,
                      onStart: () => _finish(login: false),
                      onLogin: () => _finish(login: true),
                    ),
                  ],
                ),
              ),
              // Dots + Next (last page hides Next; it has its own buttons).
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    _Dots(count: _lastIndex + 1, index: _index),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: onLast ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: FilledButton(
                        onPressed: onLast ? null : () => _animateTo(_index + 1),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('Цааш'),
                      ),
                    ),
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

/// Centres a page's content while letting it scroll when it doesn't fit —
/// small phones and large system text sizes would otherwise overflow.
class _ScrollablePage extends StatelessWidget {
  const _ScrollablePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Plays a one-shot animation each time its page becomes [active] (so swiping
/// back replays it), and resets while the page is off-screen. With the
/// platform "reduce motion" setting on, it shows the finished state instead.
class _PlayWhenActive extends StatefulWidget {
  const _PlayWhenActive({
    required this.active,
    required this.duration,
    required this.builder,
  });

  final bool active;
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_PlayWhenActive> createState() => _PlayWhenActiveState();
}

class _PlayWhenActiveState extends State<_PlayWhenActive>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _sync();
    }
  }

  @override
  void didUpdateWidget(_PlayWhenActive old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (_reduceMotion ?? false) {
      _controller.value = 1;
    } else if (widget.active) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

/// Maps overall progress [t] onto the sub-range [begin]..[end], eased.
double _interval(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeInOut,
]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.active, required this.onLogin});

  final bool active;

  /// Returning users (e.g. after a reinstall) skip the tour straight to sign-in.
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => _ScrollablePage(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/brand/mark.png', height: 56),
        const SizedBox(height: 24),
        const _PageHeading(
          title: 'Carservice-т тавтай морил',
          body:
              'Ойролцоох найдвартай засварын газраа олж, цагаа онлайнаар '
              'захиалаарай.',
        ),
        const SizedBox(height: 28),
        _PlayWhenActive(
          active: active,
          duration: const Duration(milliseconds: 2400),
          builder: (context, t) => _MapPreview(t: t),
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const ValueKey('onboarding-welcome-login'),
          onPressed: onLogin,
          child: const Text('Бүртгэлтэй юу? Нэвтрэх'),
        ),
      ],
    ),
  );
}

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage({required this.active});

  final bool active;

  static const _steps = [
    ('Олох', 'Газрын зураг дээрээс ойролцоох сервисүүдийг хараарай.'),
    ('Захиалах', 'Сул цагийг нь шалгаад шууд захиалаарай.'),
    ('Хянах', 'Захиалгын явц, түүх, оношилгооны тайлангаа хараарай.'),
  ];

  @override
  Widget build(BuildContext context) => _ScrollablePage(
    child: _PlayWhenActive(
      active: active,
      duration: const Duration(milliseconds: 2200),
      // Steps light up in turn with the connector filling between them, then
      // the sample booking flips from pending to confirmed.
      builder: (context, t) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PageHeading(
            title: 'Гурван алхамд',
            body: 'Сервисээ олохоос засвар дуустал бүгд нэг аппад.',
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < _steps.length; i++)
            _Step(
              number: i + 1,
              title: _steps[i].$1,
              body: _steps[i].$2,
              lit: _interval(t, 0.05 + i * 0.22, 0.2 + i * 0.22),
              connector: i == _steps.length - 1
                  ? null
                  : _interval(t, 0.2 + i * 0.22, 0.27 + i * 0.22),
            ),
          const SizedBox(height: 12),
          _BookingPreview(confirmed: t >= 0.85),
        ],
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.lit,
    required this.connector,
  });

  final int number;
  final String title;
  final String body;

  /// 0 → dim, 1 → fully lit.
  final double lit;

  /// Fill of the line down to the next step; `null` for the last step.
  final double? connector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimText = theme.brightness == Brightness.light
        ? AppColors.accentLightText
        : AppColors.accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color.lerp(
                  AppColors.accent.withValues(alpha: 0.16),
                  AppColors.accent,
                  lit,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color.lerp(dimText, AppColors.onAccent, lit),
                  ),
                ),
              ),
              if (connector != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: CustomPaint(
                      size: const Size(2, 0),
                      painter: _ConnectorPainter(
                        fill: connector!,
                        track: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

/// A stylised, decorative mini-map: a few service pins around the user's dot
/// and a nearest-service card — a hint of the discovery screen without shipping
/// screenshots that would drift from the real UI. Driven by [t] (0..1): a
/// route draws along the roads from the user to a service with a car
/// following it, the pin bounces on arrival, then the card fades in.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.t});

  final double t;

  static const _pinSize = 30.0;
  static const _dotSize = 16.0;

  // A pin's tip sits near the bottom of its icon box; place it on [at].
  static Widget _pinAt(Offset at, Widget pin) => Positioned(
    left: at.dx - _pinSize / 2,
    top: at.dy - _pinSize + 3,
    child: pin,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final route = _interval(t, 0.05, 0.6);
    final carOpacity = _interval(t, 0, 0.08) * (1 - _interval(t, 0.6, 0.7));
    final bounce = math.sin(math.pi * _interval(t, 0.6, 0.8, Curves.linear));
    final card = _interval(t, 0.7, 1, Curves.easeOut);
    return ExcludeSemantics(
      child: _PreviewFrame(
        height: 180,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final map = _MapGeometry(constraints.biggest);
            final metric = map.route.computeMetrics().first;
            final car = metric
                .getTangentForOffset(metric.length * route)!
                .position;
            return Stack(
              children: [
                // Road-like strokes.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoadsPainter(map, scheme.outlineVariant),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoutePainter(
                      metric.extractPath(0, metric.length * route),
                    ),
                  ),
                ),
                _pinAt(map.decorPins[0], const _Pin()),
                _pinAt(map.decorPins[1], const _Pin()),
                _pinAt(
                  map.target,
                  Transform.scale(
                    scale: 1 + 0.25 * bounce,
                    alignment: Alignment.bottomCenter,
                    child: const _Pin(),
                  ),
                ),
                Positioned(
                  left: map.user.dx - _dotSize / 2,
                  top: map.user.dy - _dotSize / 2,
                  child: Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
                Positioned(
                  left: car.dx - 11,
                  top: car.dy - 11,
                  child: Opacity(
                    opacity: carOpacity,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        size: 13,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Opacity(
                    opacity: card,
                    child: Transform.translate(
                      offset: Offset(0, (1 - card) * 8),
                      child: _MiniCard(
                        leading: const Icon(
                          Icons.build_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        title: 'Ойролцоох сервис',
                        trailing: Text(
                          '1.2 км',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A vertical line between steps, filled top-down to [fill] (0..1). Painted
/// rather than laid out so it has no intrinsic height of its own — the
/// surrounding [IntrinsicHeight] sizes it from the step text.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.fill, required this.track});

  final double fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawRect(rect, Paint()..color = track)
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * fill),
        Paint()..color = AppColors.accent,
      );
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.fill != fill || old.track != track;
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    path,
    Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );

  @override
  bool shouldRepaint(_RoutePainter old) => true;
}

/// A decorative booking card whose status flips from pending to confirmed —
/// what "track" means.
class _BookingPreview extends StatelessWidget {
  const _BookingPreview({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: _MiniCard(
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          confirmed ? Icons.event_available_rounded : Icons.schedule_rounded,
          key: ValueKey(confirmed),
          size: 18,
          color: AppColors.accent,
        ),
      ),
      title: 'Тосны солилт · Маргааш 10:00',
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: confirmed
            ? const _StatusChip(
                key: ValueKey('booking-preview-confirmed'),
                label: 'Баталгаажсан',
                color: AppColors.green,
                icon: Icons.check_rounded,
              )
            : const _StatusChip(
                key: ValueKey('booking-preview-pending'),
                label: 'Хүлээгдэж буй',
                color: AppColors.warning,
              ),
      ),
    ),
  );
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.location_on_rounded, size: 30, color: AppColors.accent);
}

/// The mini-map's layout, shared by the road drawing and the route so the car
/// drives on the roads. Coordinates are fractions of the frame (x of width,
/// y of height); the bottom ~30% is under the service card, so the user and
/// target sit above it.
class _MapGeometry {
  _MapGeometry(this.size);

  final Size size;

  Offset _p(double x, double y) => Offset(x * size.width, y * size.height);

  // Road A runs left→right, gently rising; road B runs top→bottom, leaning
  // right; road C is a curve in the top-right.
  Offset _onA(double x) => _p(x, 0.35 - 0.1 * x);
  Offset _onB(double y) => _p(0.3 + 0.15 * y, y);

  // Where A and B cross: solve x = 0.3 + 0.15y, y = 0.35 - 0.1x.
  static const _junctionX = 0.3525 / 1.015;
  static const _junctionY = 0.35 - 0.1 * _junctionX;

  Path get roadA => Path()
    ..moveTo(_onA(0).dx, _onA(0).dy)
    ..lineTo(_onA(1).dx, _onA(1).dy);

  Path get roadB => Path()
    ..moveTo(_onB(0).dx, _onB(0).dy)
    ..lineTo(_onB(1).dx, _onB(1).dy);

  Path get roadC {
    final from = _p(0.6, 0);
    final via = _p(0.7, 0.5);
    final to = _p(1, 0.6);
    return Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(via.dx, via.dy, to.dx, to.dy);
  }

  Offset get user => _onB(0.6);
  Offset get target => _onA(0.85);

  /// Non-target pins, also on roads: on B above the junction and midway along C
  /// (the quadratic's midpoint is ¼·from + ½·via + ¼·to).
  List<Offset> get decorPins => [_onB(0.22), _p(0.75, 0.4)];

  /// Up road B from the user, a rounded turn at the junction, then along
  /// road A to the target.
  Path get route {
    final start = user;
    final beforeTurn = _onB(_junctionY + 0.1);
    final corner = _onB(_junctionY);
    final afterTurn = _onA(_junctionX + 0.07);
    final end = target;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(beforeTurn.dx, beforeTurn.dy)
      ..quadraticBezierTo(corner.dx, corner.dy, afterTurn.dx, afterTurn.dy)
      ..lineTo(end.dx, end.dy);
  }
}

class _RoadsPainter extends CustomPainter {
  _RoadsPainter(this.map, this.color);

  final _MapGeometry map;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(map.roadA, paint)
      ..drawPath(map.roadB, paint)
      ..drawPath(map.roadC, paint);
  }

  @override
  bool shouldRepaint(_RoadsPainter old) =>
      old.color != color || old.map.size != map.size;
}

/// The last page: the notification ask (primed by what it's for — booking
/// confirmations) and the get-started / sign-in CTAs. Nothing here blocks
/// moving on.
class _ReadyPage extends StatefulWidget {
  const _ReadyPage({
    required this.active,
    required this.notificationService,
    required this.analytics,
    required this.onStart,
    required this.onLogin,
  });

  final bool active;
  final NotificationPermissionService notificationService;
  final AnalyticsService analytics;
  final VoidCallback onStart;
  final VoidCallback onLogin;

  @override
  State<_ReadyPage> createState() => _ReadyPageState();
}

class _ReadyPageState extends State<_ReadyPage> with WidgetsBindingObserver {
  PermissionState _notif = PermissionState.denied;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reflect the current OS state, so a revisit shows an already-granted row.
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // openSettings() returns as soon as Settings opens, not when the user comes
  // back — so the real re-read has to happen on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final notif = await widget.notificationService.check();
    if (mounted) setState(() => _notif = notif);
  }

  Future<void> _askNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Permanently denied: the OS won't prompt again, so send the user to
    // Settings; the resume hook re-reads the status when they come back.
    if (_notif == PermissionState.permanentlyDenied) {
      await widget.notificationService.openSettings();
      if (mounted) setState(() => _busy = false);
      return;
    }
    final state = await widget.notificationService.request();
    widget.analytics.logEvent('onboarding_notification_result', {
      'result': state.name,
    });
    if (mounted) {
      setState(() {
        _notif = state;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _ScrollablePage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PageHeading(
            title: 'Бэлэн боллоо!',
            body:
                'Одоо сервисээ сонгож эхлээрэй. Захиалга хийхэд бүртгэл '
                'шаардлагатай.',
          ),
          const SizedBox(height: 28),
          _PlayWhenActive(
            active: widget.active,
            duration: const Duration(milliseconds: 900),
            builder: (context, t) => _PermissionRow(
              icon: Icons.notifications_active_rounded,
              // One small ring of the bell as the page comes into view.
              iconAngle: math.sin(t * math.pi * 6) * (1 - t) * 0.3,
              title: 'Мэдэгдэл авах',
              subtitle: 'Захиалга баталгаажих, цаг ойртоход танд мэдэгдэнэ',
              state: _notif,
              keyPrefix: 'notif',
              onTap: _askNotifications,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('onboarding-start'),
              onPressed: widget.onStart,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('Эхлэх'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('onboarding-login'),
            onPressed: widget.onLogin,
            child: const Text('Бүртгэлдээ нэвтрэх'),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.keyPrefix,
    required this.onTap,
    this.iconAngle = 0,
  });

  final IconData icon;
  final double iconAngle;
  final String title;
  final String subtitle;
  final PermissionState state;
  final String keyPrefix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final granted = state == PermissionState.granted;
    // Permanently denied → the only way back is the system Settings.
    final settings = state == PermissionState.permanentlyDenied;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: iconAngle,
            alignment: Alignment.topCenter,
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  settings ? 'Тохиргооноос зөвшөөрнө үү' : subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Scales down rather than overflowing on narrow screens with large
          // text; the granted check pops in.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: granted
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('granted'),
                        color: AppColors.green,
                      )
                    : OutlinedButton(
                        key: ValueKey(
                          settings
                              ? '$keyPrefix-open-settings'
                              : '$keyPrefix-grant',
                        ),
                        onPressed: onTap,
                        child: Text(settings ? 'Тохиргоо' : 'Зөвшөөрөх'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Хуудас ${index + 1} / $count',
    child: Row(
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent
                : AppColors.accent.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    ),
  );
}
