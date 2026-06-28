import 'dart:ui';

class ScreenshotOptions {
  final bool enabled;
  final double? pixelRatio;
  final Duration delay;
  final int? maxBytes;
  final List<Rect> redactedAreas;

  const ScreenshotOptions({
    this.enabled = true,
    this.pixelRatio,
    this.delay = const Duration(milliseconds: 20),
    this.maxBytes,
    this.redactedAreas = const <Rect>[],
  });
}
