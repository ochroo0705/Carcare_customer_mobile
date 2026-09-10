import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    required this.destinations,
    required this.onLoginRequested,
    required this.onNotificationsRequested,
    super.key,
  });

  final List<Widget> destinations;
  final VoidCallback onLoginRequested;
  final VoidCallback onNotificationsRequested;

  @override
  State<CustomerShell> createState() => CustomerShellState();
}

class CustomerShellState extends State<CustomerShell>
    with SingleTickerProviderStateMixin {
  static const _profileIndex = 3;

  int _selectedIndex = 0;

  // Drives a quick scale-in of the content area whenever the tab changes. The
  // IndexedStack underneath keeps every tab mounted (state + offstage
  // semantics preserved); this just eases the swap so it isn't abrupt.
  //
  // Transform-only (scale), never opacity: tab bodies paint glass
  // (BackdropFilter), and fading a backdrop filter isolates it in an opacity
  // layer that disables the blur mid-animation then snaps it back — a visible
  // flicker of the background gradient.
  late final AnimationController _tabAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _tabScale = Tween<double>(
    begin: 0.985,
    end: 1,
  ).animate(CurvedAnimation(parent: _tabAnim, curve: Curves.easeOut));

  @override
  void dispose() {
    _tabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    // Select only the slices this shell renders, so it doesn't rebuild on
    // every unrelated change to the auth/notifications controllers (e.g. a
    // notification's read-state flipping when the unread count is unchanged).
    final account = context.select<AuthController, Account?>((c) => c.account);
    final unreadNotificationCount = context
        .select<NotificationsController, int>((c) => c.unreadCount);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final content = ScaleTransition(
          scale: _tabScale,
          child: IndexedStack(
            index: _selectedIndex,
            children: widget.destinations,
          ),
        );
        return Scaffold(
          appBar: AppBar(
            title: const CarCareBrand(compact: true),
            actions: [
              _ThemeModeMenu(controller: themeController),
              if (account != null)
                _NotificationBell(
                  unreadCount: unreadNotificationCount,
                  onTap: widget.onNotificationsRequested,
                ),
              if (account case final account?)
                _AvatarButton(
                  account: account,
                  onTap: () => _selectDestination(_profileIndex),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    key: const ValueKey('shell-login'),
                    onPressed: widget.onLoginRequested,
                    icon: const Icon(Icons.person_outline, size: 19),
                    label: const Text('Нэвтрэх'),
                  ),
                ),
            ],
          ),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore_rounded),
                          label: Text('Хайх'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.event_note_outlined),
                          selectedIcon: Icon(Icons.event_note_rounded),
                          label: Text('Захиалгууд'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long_rounded),
                          label: Text('Түүх'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: Text('Профайл'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.explore_outlined),
                      selectedIcon: Icon(Icons.explore_rounded),
                      label: 'Хайх',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.event_note_outlined),
                      selectedIcon: Icon(Icons.event_note_rounded),
                      label: 'Захиалгууд',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: 'Түүх',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Профайл',
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _tabAnim.forward(from: 0);
    }
  }

  /// Lets the router imperatively switch tabs, e.g. jumping to Appointments
  /// right after a booking succeeds — tab selection is otherwise this
  /// widget's own private state, unreachable from outside.
  void selectDestination(int index) => _selectDestination(index);
}

class _ThemeModeMenu extends StatelessWidget {
  const _ThemeModeMenu({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Өнгөний горим',
      initialValue: controller.mode,
      onSelected: controller.setMode,
      icon: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: ThemeMode.system,
          child: Text('Системийн тохиргоо'),
        ),
        PopupMenuItem(value: ThemeMode.light, child: Text('Гэрэлтэй')),
        PopupMenuItem(value: ThemeMode.dark, child: Text('Бараан')),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = IconButton(
      key: const ValueKey('shell-notifications'),
      tooltip: 'Мэдэгдэл',
      onPressed: onTap,
      icon: const Icon(Icons.notifications_outlined),
    );
    final label = unreadCount > 9 ? '9+' : '$unreadCount';
    return Badge(
      isLabelVisible: unreadCount > 0,
      label: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        // Key by value so incrementing the count pops the new number in.
        child: Text(label, key: ValueKey(label)),
      ),
      child: icon,
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.account, required this.onTap});

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _displayLabel(account);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const ValueKey('shell-avatar'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.only(right: 8, left: 4),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: scheme.primary,
          child: Text(
            label.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

String _displayLabel(Account account) {
  final name = account.name?.trim();
  return (name != null && name.isNotEmpty) ? name : account.phone;
}
