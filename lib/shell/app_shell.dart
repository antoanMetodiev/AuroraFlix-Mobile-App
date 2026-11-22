import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/current_user.dart';
// PAYMENTS DISABLED: import '../core/payments/payments.dart';
import '../core/friends/friends_store.dart';
import '../core/theme.dart';
import '../core/tv.dart';
import '../core/update/app_update.dart';
import '../core/navigation.dart';
import '../models/models.dart';
import '../screens/account/manage_account.dart';
// ASSISTANT DISABLED: import '../screens/assistant/assistant_panel.dart';
import '../screens/auth/clerk_auth_modal.dart';
import '../screens/friends/friends_modal.dart';
import '../screens/friends/notifications_panel.dart';
import '../screens/friends/watching_overlays.dart';
import '../screens/home/home_scroll.dart';
import 'nav_menu.dart';
import 'popover.dart';
import 'search_panel.dart';
import 'site_header.dart';
import 'tab_bar.dart';
import 'update_dialog.dart';
import 'user_menu.dart';

/// Padding a tab screen's scroll content needs so nothing hides under the
/// fixed header or the floating tab bar.
EdgeInsets shellContentPadding(BuildContext context) =>
    EdgeInsets.only(top: SiteHeader.reservedHeight(context), bottom: AuroraTabBar.reservedHeight(context));

/// Brief dark pill at the bottom, above the tab bar — used for "this comes
/// in a later step" until every screen exists.
void showAppToast(BuildContext context, String message, {Duration duration = const Duration(seconds: 2)}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppColors.foreground, fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        margin: EdgeInsets.fromLTRB(16, 0, 16, AuroraTabBar.reservedHeight(context) - 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.fg(0.1)),
        ),
        duration: duration,
      ),
    );
}

/// Everything around the tab screens: the fixed frosted header with its
/// search and menu dropdowns, and the floating tab bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell, required this.children});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _searchOpen = false;
  bool _menuOpen = false;
  bool _userMenuOpen = false;
  bool _bellOpen = false;

  /// The visible screen is scrolled past its top — the header island turns a
  /// little denser (same as the site's HeaderIsland).
  bool _scrolled = false;
  GoRouter? _router;

  /// Back from Stripe (checkout / billing portal run in the browser): the
  /// plan may have changed.
  late final _lifecycle = AppLifecycleListener(
    onResume: () {
      if (!ref.read(authProvider).isSignedIn) return;
      ref.invalidate(currentUserProvider);
      // PAYMENTS DISABLED: ref.invalidate(subscriptionProvider);
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // A release that needs a new APK: offer it once per launch.
    if (canSelfUpdate) {
      checkForAppUpdate(tv: ref.read(isTvProvider)).then((release) {
        if (release != null && mounted) showUpdateDialog(context, release);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router..routerDelegate.addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  /// Going anywhere (e.g. from a profile opened in the bell) closes the
  /// dropdowns.
  void _onRouteChanged() {
    if (mounted && (_searchOpen || _menuOpen || _userMenuOpen || _bellOpen)) _closePopovers();
  }

  void _closePopovers() => setState(() {
    _searchOpen = false;
    _menuOpen = false;
    _userMenuOpen = false;
    _bellOpen = false;
  });

  void _openAuth(ClerkAuthMode mode) {
    _closePopovers();
    showClerkAuthModal(context, mode);
  }

  /// Website: the Pricing link scrolls the home page to its pricing section.
  void _goToPricing() {
    _goToTab(0);
    ref.read(homeScrollRequestProvider.notifier).request(HomeAnchor.pricing);
  }

  void _goToTab(int index) {
    _closePopovers();
    // Tapping the tab you're already on takes it back to its first screen.
    widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
  }


  /// The tab the bottom bar lights up: a movie's or series' details light up
  /// Movies / Series (like the website's nav does on /movies/… and /series/…),
  /// whichever tab they were opened from; anything else, the current tab.
  int _highlightedTab(int currentIndex) {
    final path = widget.navigationShell.shellRouteContext.routerState.uri.path;
    if (path.contains('/title/movie/')) return 1;
    if (path.contains('/title/series/')) return 2;
    return currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final headerHeight = SiteHeader.reservedHeight(context);
    final anyPopoverOpen = _searchOpen || _menuOpen || _userMenuOpen || _bellOpen;

    return PopScope(
      // Android back closes an open dropdown before leaving the screen.
      canPop: !anyPopoverOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closePopovers();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (notification) {
                  // Only page scrolling — not the horizontal carousels inside.
                  if (notification.metrics.axis == Axis.vertical) {
                    final scrolled = notification.metrics.pixels > 12;
                    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
                  }
                  return false;
                },
                child: _FadingBranches(currentIndex: currentIndex, children: widget.children),
              ),
            ),

            // Tap-outside-to-close layer; the header stays above it. Always in
            // the Stack (just ignoring touches while closed) — inserting it
            // conditionally shifted every later child by one slot, so Flutter
            // rebuilt the dropdowns from scratch and lost their state.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !anyPopoverOpen,
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closePopovers),
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SiteHeader(
                scrolled: _scrolled,
                searchOpen: _searchOpen,
                menuOpen: _menuOpen || _userMenuOpen,
                onLogoTap: () => _goToTab(0),
                onSearchTap: () => setState(() {
                  _searchOpen = !_searchOpen;
                  _menuOpen = false;
                  _userMenuOpen = false;
                  _bellOpen = false;
                }),
                onMenuTap: () => setState(() {
                  _menuOpen = !(_menuOpen || _userMenuOpen);
                  _searchOpen = false;
                  _userMenuOpen = false;
                  _bellOpen = false;
                }),
                onFriendsTap: () {
                  _closePopovers();
                  showFriendsModal(context).then((_) => ref.read(friendsProvider.notifier).refresh());
                },
                onBellTap: () => setState(() {
                  _bellOpen = !_bellOpen;
                  _searchOpen = false;
                  _menuOpen = false;
                  _userMenuOpen = false;
                }),
              ),
            ),

            Positioned(
              top: headerHeight + 4,
              left: 12,
              right: 12,
              child: Popover(
                open: _searchOpen,
                alignment: Alignment.topCenter,
                child: SearchPanel(
                  open: _searchOpen,
                  // Same as the site: search series while on the Series tab.
                  initialType: currentIndex == 2 ? RecordType.series : RecordType.movie,
                  onSelect: (record) {
                    _closePopovers();
                    openRecord(context, record);
                  },
                  onSubmit: (type, query) {
                    _closePopovers();
                    openSearch(context, type, query);
                  },
                ),
              ),
            ),

            Positioned(
              top: headerHeight + 4,
              right: 16,
              child: Popover(
                open: _menuOpen,
                width: 304,
                child: NavMenu(
                  onPricing: _goToPricing,
                  // ASSISTANT DISABLED: was `_closePopovers(); showAssistantPanel(context);`
                  onAssistant: _closePopovers,
                  onSignIn: () => _openAuth(ClerkAuthMode.signIn),
                  onSignUp: () => _openAuth(ClerkAuthMode.signUp),
                  onAvatar: () => setState(() {
                    _menuOpen = false;
                    _userMenuOpen = true;
                  }),
                  onClose: _closePopovers,
                ),
              ),
            ),

            Positioned(
              top: headerHeight + 4,
              right: 16,
              child: Popover(
                open: _userMenuOpen,
                width: 304,
                bare: true,
                child: UserMenu(
                  onManageAccount: () {
                    _closePopovers();
                    showManageAccount(context);
                  },
                  onSubscription: () {
                    _closePopovers();
                    openSubscription(context);
                  },
                  onSignOut: () {
                    _closePopovers();
                    ref.read(authProvider.notifier).signOut();
                  },
                ),
              ),
            ),

            Positioned(
              top: headerHeight + 4,
              left: 12,
              right: 12,
              child: Popover(
                open: _bellOpen,
                alignment: Alignment.topCenter,
                child: NotificationsPanel(open: _bellOpen),
              ),
            ),

            if (ref.watch(authProvider.select((auth) => auth.isSignedIn))) ...[
              // Bottom-right above the tab bar, the toasts stacking over the pill.
              Positioned(right: 12, bottom: AuroraTabBar.reservedHeight(context) - 4, child: const WatchingFriendsPill()),
              Positioned(right: 12, bottom: AuroraTabBar.reservedHeight(context) + 48, child: const WatchingToasts()),
            ],

            Positioned(
              key: const ValueKey('tab-bar'),
              left: 0,
              right: 0,
              bottom: 0,
              child: AuroraTabBar(currentIndex: _highlightedTab(currentIndex), onSelect: _goToTab),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps every tab alive (scroll position, loaded data) like an IndexedStack,
/// but cross-fades between them instead of cutting. Hidden tabs don't tick
/// animations or take touches.
class _FadingBranches extends StatelessWidget {
  const _FadingBranches({required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Hidden tabs are fully offstage (not just transparent): embedded web
    // content — the hero's trailer — is a separate HTML element that
    // transparency alone doesn't hide. The tab coming in fades up.
    return Stack(
      children: [
        for (var index = 0; index < children.length; index++)
          Positioned.fill(
            child: Offstage(
              offstage: index != currentIndex,
              child: TickerMode(
                enabled: index == currentIndex,
                // Nor can a remote's arrows reach into them.
                child: ExcludeFocus(
                  excluding: index != currentIndex,
                // Same wrapper either way, so a tab's state survives switching.
                  child: _FadeInWhenActive(active: index == currentIndex, child: children[index]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FadeInWhenActive extends StatefulWidget {
  const _FadeInWhenActive({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_FadeInWhenActive> createState() => _FadeInWhenActiveState();
}

class _FadeInWhenActiveState extends State<_FadeInWhenActive> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: widget.active ? 1 : 0,
  );

  @override
  void didUpdateWidget(_FadeInWhenActive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same as the website's page transition: fades in from a little lower.
    final curve = CurvedAnimation(parent: _controller, curve: const Cubic(0.22, 1, 0.36, 1));
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.018), end: Offset.zero).animate(curve), child: widget.child),
    );
  }
}
