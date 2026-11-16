import 'package:flutter/material.dart';

import 'badges/badges_screen.dart';
import 'feed/feed_screen.dart';
import 'settings/settings_screen.dart';
import 'stats/stats_screen.dart';
import 'theme/cork_theme.dart';
import 'wishlist/wishlist_screen.dart';

typedef _Destination = ({
  String label,
  IconData icon,
  IconData selectedIcon,
  Widget screen,
});

const _destinations = <_Destination>[
  (
    label: 'Journal',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    screen: FeedScreen(),
  ),
  (
    label: 'Wishlist',
    icon: Icons.bookmark_border,
    selectedIcon: Icons.bookmark,
    screen: WishlistScreen(),
  ),
  (
    label: 'Stats',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    screen: StatsScreen(),
  ),
  (
    label: 'Badges',
    icon: Icons.military_tech_outlined,
    selectedIcon: Icons.military_tech,
    screen: BadgesScreen(),
  ),
  (
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    screen: SettingsScreen(),
  ),
];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final cork = Theme.of(context).cork;
    final body = IndexedStack(
      index: _index,
      children: [
        for (final (i, d) in _destinations.indexed)
          // Every destination's Scaffold shows each snackbar, and a snackbar
          // carries a Hero, so only the visible one may take part in heroes.
          HeroMode(
            enabled: i == _index,
            child: TickerMode(enabled: i == _index, child: d.screen),
          ),
      ],
    );
    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Material(
        color: cork.shell,
        child: Row(
          children: [
            NavigationRail(
              backgroundColor: cork.shell,
              indicatorColor: cork.shellIndicator,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: IconThemeData(color: cork.onShellIndicator),
              unselectedIconTheme: IconThemeData(color: cork.onShellVariant),
              selectedLabelTextStyle: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cork.onShell),
              unselectedLabelTextStyle: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cork.onShellVariant),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    // Not a Scaffold: each destination's own Scaffold must be a root of the
    // ScaffoldMessenger, so snackbars lift its FAB instead of covering it.
    return Material(
      color: cork.shell,
      child: Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: body,
            ),
          ),
          // NavigationBar's own SafeArea would also pad for the status bar.
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
