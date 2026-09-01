import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:flutter/material.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    required this.themeController,
    required this.destinations,
    required this.account,
    required this.onLoginRequested,
    required this.onSignOut,
    super.key,
  });

  final ThemeController themeController;
  final List<Widget> destinations;
  final Account? account;
  final VoidCallback onLoginRequested;
  final VoidCallback onSignOut;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final useRail = constraints.maxWidth >= 720;
      final content = IndexedStack(
        index: _selectedIndex,
        children: widget.destinations,
      );
      return Scaffold(
        appBar: AppBar(
          title: const CarCareBrand(compact: true),
          actions: [
            _ThemeModeMenu(controller: widget.themeController),
            if (widget.account case final account?)
              _AccountMenu(account: account, onSignOut: widget.onSignOut)
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
                        icon: Icon(Icons.favorite_border_rounded),
                        selectedIcon: Icon(Icons.favorite_rounded),
                        label: Text('Хадгалсан'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.event_note_outlined),
                        selectedIcon: Icon(Icons.event_note_rounded),
                        label: Text('Цаг'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.directions_car_outlined),
                        selectedIcon: Icon(Icons.directions_car_rounded),
                        label: Text('Машин'),
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
                    icon: Icon(Icons.favorite_border_rounded),
                    selectedIcon: Icon(Icons.favorite_rounded),
                    label: 'Хадгалсан',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note_rounded),
                    label: 'Цаг',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.directions_car_outlined),
                    selectedIcon: Icon(Icons.directions_car_rounded),
                    label: 'Машин',
                  ),
                ],
              ),
      );
    },
  );

  void _selectDestination(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }
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

enum _AccountMenuAction { signOut }

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.account, required this.onSignOut});

  final Account account;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final label = _displayLabel(account);
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_AccountMenuAction>(
      key: const ValueKey('shell-account-menu'),
      tooltip: 'Профайл',
      onSelected: (action) {
        if (action == _AccountMenuAction.signOut) onSignOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountMenuAction>(
          enabled: false,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AccountMenuAction.signOut,
          child: Text('Гарах'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
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
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

String _displayLabel(Account account) {
  final name = account.name?.trim();
  return (name != null && name.isNotEmpty) ? name : account.phone;
}
