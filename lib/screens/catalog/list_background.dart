import 'package:flutter/material.dart';

/// The movies / series lists' background — the website's ListBackground (genre
/// and title-search results included): plain black.
class ListBackground extends StatelessWidget {
  const ListBackground({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
