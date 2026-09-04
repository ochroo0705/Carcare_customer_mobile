import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/core/permissions/notification_permission_service.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:flutter/material.dart';

/// First-run onboarding: welcome → discover/book → track → permissions →
/// get-started (with a skippable soft-login). Shown once; [onFinish] fires when
/// the user finishes or skips — `login: true` means route them to sign-in,
/// `false` means drop them into the app to browse.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onFinish,
    this.locationService = const PermissionHandlerLocationPermissionService(),
    this.notificationService =
        const PermissionHandlerNotificationPermissionService(),
    super.key,
  });

  final void Function({required bool login}) onFinish;
  final LocationPermissionService locationService;
  final NotificationPermissionService notificationService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  late final int _lastIndex;

  @override
  void initState() {
    super.initState();
    _lastIndex = 4; // welcome, discover, track, permissions, ready
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _lastIndex) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onLast = _index == _lastIndex;
    return Scaffold(
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
                    onPressed: onLast
                        ? null
                        : () => widget.onFinish(login: false),
                    child: const Text('Алгасах'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  const _InfoPage(
                    image: 'assets/brand/mark.png',
                    title: 'Carservice-т тавтай морил',
                    body: 'Найдвартай засварын газраа олж, цагаа онлайнаар '
                        'захиалах хялбар арга.',
                  ),
                  const _InfoPage(
                    icon: Icons.travel_explore_rounded,
                    title: 'Ойролцоох сервисээ олоорой',
                    body: 'Газрын зураг дээрээс ойролцоох засварын газруудыг '
                        'хараад, цагийн хуваарийг нь шалгаж, шууд захиалаарай.',
                  ),
                  const _InfoPage(
                    icon: Icons.receipt_long_rounded,
                    title: 'Бүгдийг нэг дор хянаарай',
                    body: 'Цаг захиалга, үйлчилгээний түүх, оношилгооны '
                        'тайлангаа аппаасаа шууд хараарай.',
                  ),
                  _PermissionsPage(
                    locationService: widget.locationService,
                    notificationService: widget.notificationService,
                  ),
                  _ReadyPage(
                    onStart: () => widget.onFinish(login: false),
                    onLogin: () => widget.onFinish(login: true),
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
                      onPressed: onLast ? null : _next,
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
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.body,
    this.icon,
    this.image,
  });

  final String title;
  final String body;
  final IconData? icon;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: image != null
                ? Padding(
                    padding: const EdgeInsets.all(26),
                    child: Image.asset(image!, fit: BoxFit.contain),
                  )
                : Icon(icon, size: 60, color: AppColors.amber),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// The permissions page — requests notifications + location via the OS prompts
/// (the user's chosen "ask during onboarding" model). Each row reflects its
/// granted state; nothing here blocks moving on.
class _PermissionsPage extends StatefulWidget {
  const _PermissionsPage({
    required this.locationService,
    required this.notificationService,
  });

  final LocationPermissionService locationService;
  final NotificationPermissionService notificationService;

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage> {
  PermissionState _notif = PermissionState.denied;
  PermissionState _loc = PermissionState.denied;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Reflect the current OS state, so a revisit (or a return from Settings)
    // shows already-granted rows correctly.
    _refresh();
  }

  Future<void> _refresh() async {
    final notif = await widget.notificationService.check();
    final loc = _locFrom(await widget.locationService.check());
    if (mounted) {
      setState(() {
        _notif = notif;
        _loc = loc;
      });
    }
  }

  PermissionState _locFrom(LocationAccessState s) => switch (s) {
    LocationAccessState.granted => PermissionState.granted,
    LocationAccessState.permanentlyDenied => PermissionState.permanentlyDenied,
    LocationAccessState.denied => PermissionState.denied,
  };

  Future<void> _askNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = _notif == PermissionState.permanentlyDenied
        ? await _openSettingsThenRecheck(widget.notificationService.openSettings,
            widget.notificationService.check)
        : await widget.notificationService.request();
    if (mounted) {
      setState(() {
        _notif = state;
        _busy = false;
      });
    }
  }

  Future<void> _askLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = _loc == PermissionState.permanentlyDenied
        ? _locFrom(await _openSettingsThenRecheckLoc())
        : _locFrom(await widget.locationService.request());
    if (mounted) {
      setState(() {
        _loc = state;
        _busy = false;
      });
    }
  }

  // Permanently denied: the OS won't prompt again, so send the user to Settings,
  // then re-read the status when they come back.
  Future<PermissionState> _openSettingsThenRecheck(
    Future<bool> Function() openSettings,
    Future<PermissionState> Function() check,
  ) async {
    await openSettings();
    return check();
  }

  Future<LocationAccessState> _openSettingsThenRecheckLoc() async {
    await widget.locationService.openSettings();
    return widget.locationService.check();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Аппыг бүрэн ашиглахын тулд',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Доорх зөвшөөрлүүдийг өгснөөр илүү тохиромжтой болно. '
            'Хүсвэл дараа ч тохируулж болно.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          _PermissionRow(
            icon: Icons.notifications_active_rounded,
            title: 'Мэдэгдэл',
            subtitle: 'Захиалгын хариу, сануулга хүлээн авах',
            state: _notif,
            keyPrefix: 'notif',
            onTap: _askNotifications,
          ),
          const SizedBox(height: 14),
          _PermissionRow(
            icon: Icons.location_on_rounded,
            title: 'Байршил',
            subtitle: 'Ойролцоох сервисүүдийг харуулах',
            state: _loc,
            keyPrefix: 'loc',
            onTap: _askLocation,
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
  });

  final IconData icon;
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.amber),
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
                  settings
                      ? 'Тохиргооноос зөвшөөрнө үү'
                      : subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (granted)
            const Icon(Icons.check_circle_rounded, color: AppColors.green)
          else
            OutlinedButton(
              key: ValueKey(
                settings ? '$keyPrefix-open-settings' : '$keyPrefix-grant',
              ),
              onPressed: onTap,
              child: Text(settings ? 'Тохиргоо' : 'Зөвшөөрөх'),
            ),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage({required this.onStart, required this.onLogin});

  final VoidCallback onStart;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_rounded,
              size: 64,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Бэлэн боллоо!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Одоо сервисээ сонгож эхлээрэй. Захиалга хийхэд бүртгэл шаардлагатай.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('onboarding-start'),
              onPressed: onStart,
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
            onPressed: onLogin,
            child: const Text('Бүртгэлдээ нэвтрэх'),
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
  Widget build(BuildContext context) => Row(
    children: List.generate(count, (i) {
      final active = i == index;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 6),
        width: active ? 22 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active
              ? AppColors.amber
              : AppColors.amber.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }),
  );
}
