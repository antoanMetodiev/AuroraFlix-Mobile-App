import 'package:flutter/material.dart';

/// The movies / series lists' background — the website's ListBackground (genre
/// and title-search results included): no image, just a soft dark gradient —
/// a faint charcoal glow at the top melting into black, with a vignette.
class ListBackground extends StatelessWidget {
  const ListBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF161616), Color(0xFF080808), Color(0xFF000000)],
            ),
          ),
        ),
        // The site's faint white glow from the top centre.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 0.9,
              colors: [Color(0x0FFFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.7],
            ),
          ),
        ),
        // Vignette toward the edges.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [Color(0x00000000), Color(0xD9000000)],
              stops: [0.4, 1],
            ),
          ),
        ),
      ],
    );
  }
}
