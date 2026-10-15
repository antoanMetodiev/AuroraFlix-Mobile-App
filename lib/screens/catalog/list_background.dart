import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../models/models.dart';
import '../details/details_background.dart';

/// The movies / series lists' background — the website's ListBackground: a
/// fixed still of their own (genre and title-search results included) under
/// the same blur, shade and vignette as the details screen's background.
///
/// Loaded from the website rather than bundled, so changing it never needs a
/// new build — Shorebird patches can't add assets.
class ListBackground extends StatelessWidget {
  const ListBackground({super.key, required this.type});

  final RecordType type;

  @override
  Widget build(BuildContext context) =>
      BlurredPageBackdrop(url: type == RecordType.movie ? '$siteUrl/movie-background-image.webp' : '$siteUrl/series-background-image.webp');
}
