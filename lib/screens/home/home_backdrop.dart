import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../details/details_background.dart';

/// The home screen's blurred page background (everything below the hero) —
/// the website's HomeBackdrop: a random trending poster, picked anew every
/// time the home tab is opened, never the same one twice in a row.
///
/// The shell keeps the home tab alive while you're on other tabs, with its
/// tickers off (TickerMode), so "opened again" is TickerMode turning back on.
class HomeBackdrop extends StatefulWidget {
  const HomeBackdrop({super.key, required this.posters});

  /// TMDB poster paths of the trending titles.
  final List<String> posters;

  @override
  State<HomeBackdrop> createState() => _HomeBackdropState();
}

class _HomeBackdropState extends State<HomeBackdrop> {
  static final _random = math.Random();

  /// Remembered across the tab's lifetimes, like the site's sessionStorage.
  static String? _last;

  String? _path;
  bool? _wasActive;

  void _pick() {
    final posters = widget.posters;
    if (posters.isEmpty) return;
    final candidates = posters.length > 1 ? posters.where((poster) => poster != _last).toList() : posters;
    _path = candidates[_random.nextInt(candidates.length)];
    _last = _path;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    // First build, or the tab just came back into view.
    if (_wasActive == null || (active && _wasActive == false)) _pick();
    _wasActive = active;
  }

  @override
  void didUpdateWidget(HomeBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trending (re)loaded — e.g. pull to refresh — and nothing picked yet.
    if (_path == null || !widget.posters.contains(_path)) _pick();
  }

  @override
  Widget build(BuildContext context) => BlurredPageBackdrop(path: _path);
}
