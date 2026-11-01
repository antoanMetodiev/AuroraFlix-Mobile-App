import 'package:flutter/material.dart';

/// The movies / series lists' background — the website's ListBackground (genre
/// and title-search results included): no image, just a dark gradient — a
/// charcoal glow over the top melting into black further down, with a light
/// vignette.
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
              colors: [Color(0xFF262626), Color(0xFF121212), Color(0xFF000000)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        // The site's white glow from the top centre.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.3,
              colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.75],
            ),
          ),
        ),
        // Vignette toward the edges.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [Color(0x00000000), Color(0xB3000000)],
              stops: [0.55, 1],
            ),
          ),
        ),
      ],
    );
  }
}
