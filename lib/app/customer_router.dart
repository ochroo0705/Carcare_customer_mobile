import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/app/customer_navigation.dart';
import 'package:carcare_customer_mobile/app/customer_routes.dart';
import 'package:carcare_customer_mobile/app/customer_shell.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_payment_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointments_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/walk_in_order_detail_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/service_key_picker_screen.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/screens/diagnostic_detail_screen.dart';
import 'package:carcare_customer_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:carcare_customer_mobile/features/history/presentation/screens/service_order_detail_screen.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/account_closure_screen.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/add_vehicle_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/vehicle_detail_screen.dart';
import 'package:carcare_customer_mobile/core/widgets/skeletons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Pure function so it is unit-testable without a widget tree. Encodes the
/// only two guards in the route table (booking requires auth; account
/// closure requires auth) plus the `/login` forward-once-signed-in rule.
String? customerRedirect({required bool isAuthenticated, required Uri uri}) {
  final segments = uri.pathSegments;
  final isBooking =
      segments.length == 3 &&
      segments[0] == 'organizations' &&
      segments[2] == 'book';
  if (isBooking && !isAuthenticated) {
    return CustomerRoutes.login(from: uri.toString());
  }
  if (uri.path == CustomerRoutes.accountClosure && !isAuthenticated) {
    return CustomerRoutes.shell;
  }
  if (uri.path == '/login' && isAuthenticated) {
    return uri.queryParameters['from'];
  }
  return null;
}

/// Booking tab's cross-org service-key picker preselects (and locks) the
/// categories on the chosen branch that map to the picked service keys.
/// Moved out of the delegate (router.dart:451-463) as a top-level function so
/// it is unit-testable without a widget tree.
List<String> resolveLockedCategoryIds(
  OrganizationDetail organization,
  String? branchId,
  Set<String> keyIds,
) {
  if (branchId == null) return const [];
  final branch = organization.branches
      .where((b) => b.id == branchId)
      .toList(growable: false);
  if (branch.isEmpty) return const [];
  return branch.first.categories
      .where((c) => keyIds.contains(c.systemServiceKeyId))
      .map((c) => c.id)
      .toList(growable: false);
}

/// Returns the `GoRouter` for the customer app. Every route is top-level
/// (see the route table in `plan-context.md`); the app opens them with
/// `push`, so the stack order is the order the customer opened them.
GoRouter buildCustomerRouter(
  CustomerAppServices services,
  CustomerNavigation navigation,
) {
  return GoRouter(
    initialLocation: CustomerRoutes.shell,
    refreshListenable: services.routerRefresh,
    redirect: (context, state) => customerRedirect(
      isAuthenticated: services.authController.isAuthenticated,
      uri: state.uri,
    ),
    // An unknown path lands on the shell, as the old parser's
    // `DiscoveryRoutePath` fallback did. Do not also set `errorBuilder`;
    // go_router asserts if both are set.
    onException: (context, state, router) => router.go(CustomerRoutes.shell),
    routes: [
      GoRoute(
        path: CustomerRoutes.shell,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: CustomerShell(
            key: navigation.shellKey,
            onLoginRequested: navigation.requestLogin,
            onNotificationsRequested: () =>
                context.push(CustomerRoutes.notifications),
            destinations: [
              DiscoveryScreen(
                onBranchSelected: (org, branch) => context.push(
                  CustomerRoutes.organization(org.slug, branchId: branch.id),
                ),
                onNotificationsRequested: () =>
                    context.push(CustomerRoutes.notifications),
              ),
              ServiceKeyPickerScreen(
                repository: services.organizationRepository,
                onBranchSelected: (org, branch, keys) => context.push(
                  CustomerRoutes.booking(
                    org.slug,
                    branchId: branch.id,
                    serviceKeyIds: keys.map((k) => k.id).toList(),
                  ),
                ),
              ),
              AppointmentsScreen(
                onLoginRequested: navigation.requestLogin,
                onAppointmentSelected: (id) => navigation.openAppointment(id),
                onPaymentRequested: (appointment) => context.push(
                  CustomerRoutes.payment(appointment.id),
                  extra: appointment.payment,
                ),
                onWalkInOrderSelected: (id) =>
                    context.push(CustomerRoutes.walkInOrder(id)),
              ),
              HistoryScreen(
                onLoginRequested: navigation.requestLogin,
                onOrderSelected: (id) => context.push(CustomerRoutes.order(id)),
                diagnosticsRepository: services.diagnosticsRepository,
                onDiagnosticReportSelected: (id) =>
                    context.push(CustomerRoutes.diagnostic(id)),
              ),
              ProfileScreen(
                onLoginRequested: navigation.requestLogin,
                onAddVehicle: () => context.push(CustomerRoutes.addVehicle),
                onVehicleSelected: (v) =>
                    context.push(CustomerRoutes.vehicle(v.id), extra: v),
                onAccountClosureRequested: () =>
                    context.push(CustomerRoutes.accountClosure),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/organizations/:slug',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final branchId = state.uri.queryParameters['branch'];
          return MaterialPage(
            key: state.pageKey,
            child: _OrganizationScope(
              slug: slug,
              services: services,
              builder: (context, c, reload) => OrganizationDetailScreen(
                organization: c.organization,
                distanceLocation: services.discoveryController.nearMeLocation,
                branchId: branchId,
                status: c.status,
                errorMessage: c.message,
                onRetry: reload,
                onBack: () => context.pop(),
                onBook: () => context.push(
                  CustomerRoutes.booking(
                    slug,
                    branchId: branchId,
                    lockBranch: branchId != null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/organizations/:slug/book',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final branchId = state.uri.queryParameters['branch'];
          final lock = state.uri.queryParameters['lock'];
          final keysParam = state.uri.queryParameters['keys'];
          final keyIds = (keysParam == null || keysParam.isEmpty)
              ? const <String>{}
              : keysParam.split(',').toSet();
          return MaterialPage(
            key: state.pageKey,
            child: _OrganizationScope(
              slug: slug,
              services: services,
              builder: (context, c, reload) {
                final organization = c.organization;
                if (c.status == OrganizationDetailStatus.error) {
                  return Scaffold(
                    appBar: AppBar(leading: BackButton(onPressed: context.pop)),
                    body: OrganizationLoadError(
                      message: c.message ?? 'Мэдээлэл ачаалсангүй.',
                      onRetry: reload,
                    ),
                  );
                }
                if (organization == null || organization.slug != slug) {
                  return Scaffold(
                    appBar: AppBar(),
                    body: const SkeletonDetail(),
                  );
                }
                return BookingRequestScreen(
                  organization: organization,
                  initialBranchId: branchId,
                  repository: services.appointmentRepository,
                  onAddVehicle: () => context.push(CustomerRoutes.addVehicle),
                  onBack: () => context.pop(),
                  lockCategories: keyIds.isNotEmpty,
                  lockBranch: lock == '1',
                  initialCategoryIds: keyIds.isEmpty
                      ? null
                      : resolveLockedCategoryIds(
                          organization,
                          branchId,
                          keyIds,
                        ),
                  // `BookingRequestScreen.onUnauthenticated` fires when a
                  // `createAppointment` call comes back 401 while this page
                  // is already showing (a session the client hadn't noticed
                  // was invalid). Unlike the initial signed-out tap on
                  // "Цаг захиалах" (caught by `customerRedirect`, since that
                  // is a genuine navigation to this route), this happens
                  // while already ON the booking route — `redirect`'s
                  // `refreshListenable`-triggered re-evaluation only ever
                  // reconsiders the base `go()` location, never a `push`ed
                  // route's own URL, so signing out here would otherwise
                  // strand the customer on a booking form with no
                  // repository session and no way back to login. So this
                  // navigates explicitly, same as the old delegate's
                  // `_showLogin = true`. Unlike the redirect path (where
                  // signing in has to resume TO this route because it was
                  // never reached), this booking page is already mounted and
                  // stays on the stack underneath — pushing `/login` WITHOUT
                  // `from` means a successful sign-in's `onAuthenticated`
                  // just `pop()`s back to this same still-live page, instead
                  // of `pushReplacement`ing a second, duplicate booking page
                  // on top of it.
                  onUnauthenticated: () {
                    services.authController.clearConfirmedUnauthorized().then((
                      _,
                    ) {
                      if (context.mounted) {
                        context.push(CustomerRoutes.login());
                      }
                    });
                  },
                  onCompleted: navigation.completeBooking,
                );
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          final from = state.uri.queryParameters['from'];
          return MaterialPage(
            key: state.pageKey,
            child: LoginScreen(
              onBack: () {
                services.authController.resetFlow();
                context.pop();
              },
              onAuthenticated: () {
                // Deferred to the next frame: `notifyListeners()` from
                // `verifyOtp` (which flips `isAuthenticated`) reaches
                // go_router's own `refreshListenable` listener before this
                // callback runs (both are listeners on the same
                // `AuthController`, and go_router's redirect re-evaluation is
                // scheduled as a microtask that beats the awaited
                // `verifyOtp()` future's own continuation back here). That
                // in-flight refresh transiently invalidates the current
                // `BuildContext`/route match, so a `pop()`/`pushReplacement()`
                // issued synchronously in this callback is silently lost —
                // the login page then never closes. Posting to the next
                // frame lets go_router's own refresh settle first.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  if (from == null) {
                    context.pop();
                  } else {
                    context.pushReplacement(from);
                  }
                });
              },
            ),
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.addVehicle,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: AddVehicleScreen(
            repository: services.vehicleRepository,
            onBack: () => context.pop(),
            onAdded: (vehicle) {
              context.pop();
              services.vehiclesController.load();
              services.showMessage?.call('Машин нэмэгдлээ.');
            },
          ),
        ),
      ),
      GoRoute(
        path: '/vehicles/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final extraVehicle = state.extra as Vehicle?;
          final fallback = extraVehicle ?? _findVehicle(services, id);
          if (fallback == null) {
            return MaterialPage(
              key: state.pageKey,
              child: Scaffold(
                appBar: AppBar(
                  leading: BackButton(onPressed: () => context.pop()),
                ),
                body: const Center(child: Text('Машин олдсонгүй.')),
              ),
            );
          }
          return MaterialPage(
            key: state.pageKey,
            child: VehicleDetailScreen(
              vehicleId: id,
              fallbackVehicle: fallback,
              onAppointmentSelected: (id) => navigation.openAppointment(id),
              onOrderSelected: (id) => context.push(CustomerRoutes.order(id)),
              onBack: () => context.pop(),
              onRefreshHur: () => navigation.refreshVehicleFromHur(id),
            ),
          );
        },
      ),
      GoRoute(
        path: '/appointments/:id',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: AppointmentDetailScreen(
            appointmentId: state.pathParameters['id']!,
            organizationRepository: services.organizationRepository,
            onBack: () => context.pop(),
            onPay: (appointment) => context.push(
              CustomerRoutes.payment(appointment.id),
              extra: appointment.payment,
            ),
            onReportSelected: (id) =>
                context.push(CustomerRoutes.diagnostic(id)),
          ),
        ),
      ),
      GoRoute(
        path: '/appointments/:id/pay',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: AppointmentPaymentScreen(
            appointmentId: state.pathParameters['id']!,
            repository: services.appointmentRepository,
            initialPayment: state.extra as AppointmentPayment?,
            onBack: () => context.pop(),
            onPaymentUpdated: services.appointmentsController.load,
          ),
        ),
      ),
      GoRoute(
        path: '/walk-in-orders/:id',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: WalkInOrderDetailScreen(
            orderId: state.pathParameters['id']!,
            onBack: () => context.pop(),
            onReportSelected: (id) =>
                context.push(CustomerRoutes.diagnostic(id)),
          ),
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: ServiceOrderDetailScreen(
            repository: services.historyRepository,
            orderId: state.pathParameters['id']!,
            onBack: () => context.pop(),
            historyController: services.historyController,
            onReportSelected: (id) =>
                context.push(CustomerRoutes.diagnostic(id)),
          ),
        ),
      ),
      GoRoute(
        path: '/diagnostics/:id',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: DiagnosticDetailScreen(
            repository: services.diagnosticsRepository,
            reportId: state.pathParameters['id']!,
            onBack: () => context.pop(),
          ),
        ),
      ),
      GoRoute(
        path: CustomerRoutes.notifications,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: NotificationsScreen(
            onBack: () => context.pop(),
            onOpen: (n) => navigation.openFromPush(n.data, fromList: true),
          ),
        ),
      ),
      GoRoute(
        path: CustomerRoutes.accountClosure,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: _AccountClosureRoute(
            onClosed: () => context.go(CustomerRoutes.shell),
          ),
        ),
      ),
    ],
  );
}

/// The account-closure page is reached with a `push`, and go_router's
/// `refreshListenable`-triggered redirect re-evaluation only ever
/// reconsiders the base `go()` location — never a `push`ed route's own URL
/// (same limitation documented on the booking route's `onUnauthenticated`
/// above). So `customerRedirect` alone never pops this page when the
/// customer signs out while it's open; it only stops a *fresh* navigation
/// to `/account/close` while already signed out. This widget closes that
/// gap explicitly: it watches `AuthController` directly (a plain Provider
/// rebuild, not a redirect race) and calls [onClosed] once
/// `isAuthenticated` flips to false while this page is still mounted.
/// Deferred to the next frame for the same reason the login route's
/// `onAuthenticated` callback is: acting synchronously inside a listener
/// callback that fires from the very same `notifyListeners()` go_router's
/// own redirect re-evaluation is also reacting to can be silently lost.
class _AccountClosureRoute extends StatefulWidget {
  const _AccountClosureRoute({required this.onClosed});

  final VoidCallback onClosed;

  @override
  State<_AccountClosureRoute> createState() => _AccountClosureRouteState();
}

class _AccountClosureRouteState extends State<_AccountClosureRoute> {
  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthController, bool>(
      (c) => c.isAuthenticated,
    );
    if (!isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) widget.onClosed();
      });
    }
    return AccountClosureScreen(onClosed: widget.onClosed);
  }
}

Vehicle? _findVehicle(CustomerAppServices services, String id) {
  for (final v in services.vehiclesController.state.vehicles) {
    if (v.id == id) return v;
  }
  return null;
}

/// A read-only snapshot of the shared `OrganizationDetailController`, scoped
/// to whichever slug a particular `_OrganizationScope` cares about — never
/// the controller itself, so a stale-slug scope can't be handed the other
/// scope's live data by mistake.
typedef _OrgScopeState = ({
  OrganizationDetail? organization,
  OrganizationDetailStatus status,
  String? message,
});

const _loadingOrgScopeState = (
  organization: null,
  status: OrganizationDetailStatus.loading,
  message: null,
);

/// Loads the organization detail (if not already loaded for [slug]) once,
/// then rebuilds only itself — not the router — whenever the detail
/// controller changes, satisfying the `31dcc14` router-rebuild invariant.
///
/// `organizationDetailController` is shared across every `_OrganizationScope`
/// on the navigation stack (one controller, potentially several scopes —
/// e.g. an org-detail page underneath a booking page for the SAME org, or
/// two different orgs visited in a row without popping the first). Because
/// each scope keeps watching the controller for as long as it's mounted —
/// including while another scope is the one actually on top and driving
/// loads — a scope whose own slug no longer matches what the controller
/// currently holds must never render that mismatched data: it renders the
/// loading state instead and schedules its own reload.
class _OrganizationScope extends StatefulWidget {
  const _OrganizationScope({
    required this.slug,
    required this.services,
    required this.builder,
  });

  final String slug;
  final CustomerAppServices services;
  final Widget Function(
    BuildContext context,
    _OrgScopeState state,
    VoidCallback reload,
  )
  builder;

  @override
  State<_OrganizationScope> createState() => _OrganizationScopeState();
}

class _OrganizationScopeState extends State<_OrganizationScope> {
  bool _reloadScheduled = false;

  OrganizationDetailController get _controller =>
      widget.services.organizationDetailController;

  @override
  void initState() {
    super.initState();
    if (_controller.organization?.slug != widget.slug) {
      _scheduleReload();
    }
  }

  void _reload() => _controller.load(widget.slug);

  /// Defers to the next frame rather than calling `_reload` directly:
  /// `OrganizationDetailController.load` synchronously calls
  /// `notifyListeners`, which must never happen mid-build. This is reached
  /// both from `initState` — while this very page is still being mounted,
  /// which is itself a build in progress — and from `build`, when a stale
  /// slug is detected on a rebuild.
  void _scheduleReload() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadScheduled = false;
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrganizationDetailController>();
    final matchesSlug = controller.organization?.slug == widget.slug;
    // A failed load for this very slug is a settled state, not a mismatch:
    // show it and wait for the user's retry instead of reloading forever.
    if (!matchesSlug &&
        controller.status == OrganizationDetailStatus.error &&
        controller.requestedSlug == widget.slug) {
      return widget.builder(context, (
        organization: null,
        status: controller.status,
        message: controller.message,
      ), _reload);
    }
    if (!matchesSlug) {
      // Only the topmost (currently active) route ever corrects the shared
      // controller back to its own slug. Every mismatched scope still
      // mounted underneath it — offstage, but still watching the same
      // controller — must NOT also try to reload for itself: two scopes
      // both "fixing" the controller back to their own slug would bounce it
      // back and forth forever every time the other one's fix lands (a real
      // risk, not hypothetical: the fake repo's cache makes a correcting
      // reload synchronous, so nothing would ever pace the two out). Skip
      // scheduling a reload while a load is already in flight too — for
      // this slug or any other — since the in-flight load's own completion
      // triggers a rebuild that re-checks all of this anyway.
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrent && controller.status != OrganizationDetailStatus.loading) {
        _scheduleReload();
      }
      return widget.builder(context, _loadingOrgScopeState, _reload);
    }
    return widget.builder(context, (
      organization: controller.organization,
      status: controller.status,
      message: controller.message,
    ), _reload);
  }
}
