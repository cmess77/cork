import 'package:flutter/material.dart';

Route<T> corkRoute<T>(BuildContext context, WidgetBuilder builder) =>
    _CorkRoute<T>(
      builder: builder,
      instant: MediaQuery.disableAnimationsOf(context),
    );

final class _CorkRoute<T> extends MaterialPageRoute<T> {
  _CorkRoute({required super.builder, required this.instant});
  final bool instant;

  @override
  Duration get transitionDuration =>
      instant ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      instant ? Duration.zero : super.reverseTransitionDuration;
}
