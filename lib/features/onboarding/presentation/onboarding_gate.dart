import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/core/permissions/notification_permission_service.dart';
import 'package:carcare_customer_mobile/features/discovery/services/location_permission_service.dart';
import 'package:carcare_customer_mobile/features/onboarding/data/onboarding_store.dart';
import 'package:carcare_customer_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';

/// Shows [OnboardingScreen] once on first run, then the app. Sits inside the
/// splash (so the app subtree still isn't built during onboarding) and calls
/// [onRequestLogin] when the user finishes via "Бүртгэлдээ нэвтрэх".
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    required this.child,
    required this.onRequestLogin,
    this.store = const OnboardingStore(),
    this.locationService = const PermissionHandlerLocationPermissionService(),
    this.notificationService =
        const PermissionHandlerNotificationPermissionService(),
    super.key,
  });

  final Widget child;
  final VoidCallback onRequestLogin;
  final OnboardingStore store;
  final LocationPermissionService locationService;
  final NotificationPermissionService notificationService;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _completed; // null while the flag is being read

  @override
  void initState() {
    super.initState();
    if (debugDisableAppBootstrap) return; // tests: render child directly
    widget.store.hasCompleted().then((value) {
      if (mounted) setState(() => _completed = value);
    });
  }

  Future<void> _finish({required bool login}) async {
    await widget.store.markCompleted();
    if (!mounted) return;
    setState(() => _completed = true);
    if (login) widget.onRequestLogin();
  }

  @override
  Widget build(BuildContext context) {
    if (debugDisableAppBootstrap) return widget.child;
    // While the flag is unknown, render nothing heavy — the splash still covers
    // the screen at this point, so there is no visible gap.
    if (_completed == null) return const SizedBox.expand();
    if (_completed!) return widget.child;
    return OnboardingScreen(
      onFinish: _finish,
      locationService: widget.locationService,
      notificationService: widget.notificationService,
    );
  }
}
