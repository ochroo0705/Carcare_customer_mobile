import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:flutter/material.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    required this.themeController,
    required this.destinations,
    super.key,
  });

  final ThemeController themeController;
  final List<Widget> destinations;

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
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () {},
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
