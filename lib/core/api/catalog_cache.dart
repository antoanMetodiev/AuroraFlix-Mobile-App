import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long trending and the top-rated picks ("Popular", "Similar titles")
/// stay cached — the website keeps them 30 minutes in its edge cache.
const curatedCacheTtl = Duration(minutes: 30);

/// How long a /movies or /series page (and its count) stays cached — the
/// website's 5 minutes.
const listingCacheTtl = Duration(minutes: 5);

/// While the catalog counts as "just ordered into", listings go stale this
/// fast instead, so the new title shows up within seconds of being added.
const freshListingCacheTtl = Duration(seconds: 15);

DateTime? _freshUntil;

/// Called after a successful order (the Order screen, or a search that found
/// nothing): for the next 10 minutes listings refetch almost right away —
/// the website's lib/fresh-catalog.ts cookie.
void markCatalogFresh() => _freshUntil = DateTime.now().add(const Duration(minutes: 10));

bool get catalogIsFresh {
  final until = _freshUntil;
  return until != null && DateTime.now().isBefore(until);
}

/// Drops this provider's value after [ttl], so the next read fetches again
/// (a screen still showing it refreshes in place, keeping the old data up).
void expireAfter(Ref ref, Duration ttl) {
  final timer = Timer(ttl, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}
