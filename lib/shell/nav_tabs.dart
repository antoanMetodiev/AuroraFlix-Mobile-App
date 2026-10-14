import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The six primary destinations — same order, icons and labels as the
/// website's NAV_LINKS / MobileTabBar.
class NavTab {
  const NavTab({required this.path, required this.labelKey, required this.icon, this.shortLabelKey});

  final String path;
  final String labelKey;

  /// The tab bar has no room for the long label on a phone.
  final String? shortLabelKey;
  final IconData icon;
}

const navTabs = [
  NavTab(path: '/', labelKey: 'nav.home', icon: LucideIcons.house),
  NavTab(path: '/movies', labelKey: 'nav.movies', icon: LucideIcons.clapperboard),
  NavTab(path: '/series', labelKey: 'nav.series', icon: LucideIcons.tv),
  NavTab(path: '/watchlist', labelKey: 'nav.watchlist', shortLabelKey: 'nav.watchlistShort', icon: LucideIcons.bookmark),
  NavTab(path: '/playlists', labelKey: 'nav.playlists', shortLabelKey: 'nav.playlistsShort', icon: LucideIcons.listVideo),
  NavTab(path: '/order', labelKey: 'nav.order', icon: LucideIcons.circlePlus),
];
