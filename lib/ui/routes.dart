import 'package:flutter/material.dart';

import '../domain/feed.dart';
import '../domain/ids.dart';
import 'feed/feed_screen.dart';
import 'search/wine_search_screen.dart';
import 'tasting/cork_route.dart';
import 'wine/wine_detail_screen.dart';

Future<void> openFilteredFeed(BuildContext context, FeedFilter filter) =>
    Navigator.push<void>(
      context,
      corkRoute(context, (_) => FeedScreen(initialFilter: filter)),
    );

Future<void> openWine(BuildContext context, WineId id, {TastingId? expand}) =>
    Navigator.push<void>(
      context,
      corkRoute(context, (_) => WineDetailScreen(id: id, expand: expand)),
    );

Future<void> logGlass(BuildContext context) => Navigator.push<void>(
  context,
  corkRoute(context, (_) => const WineSearchScreen()),
);
