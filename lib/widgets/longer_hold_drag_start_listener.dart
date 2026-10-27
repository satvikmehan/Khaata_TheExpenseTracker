import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LongerHoldDragStartListener extends ReorderableDragStartListener {
  final Duration delay;

  const LongerHoldDragStartListener({
    super.key,
    required super.child,
    required super.index,
    super.enabled,
    this.delay = const Duration(milliseconds: 1000),
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: delay,
      debugOwner: this,
    );
  }
}
