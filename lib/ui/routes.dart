import 'package:flutter/material.dart';

import '../domain/feed.dart';
import '../domain/ids.dart';

/// Cross-screen navigation, so a screen never imports another screen's
/// internals to open it.
Future<void> openFilteredFeed(BuildContext context, FeedFilter filter) async {}

Future<void> openWine(
  BuildContext context,
  WineId id, {
  TastingId? expand,
}) async {}
