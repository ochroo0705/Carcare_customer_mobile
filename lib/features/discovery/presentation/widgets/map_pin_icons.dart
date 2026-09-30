import 'dart:ui' as ui;

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The three branded map pins: open (green), closed (neutral), selected.
typedef MapPinIcons = ({
  BitmapDescriptor open,
  BitmapDescriptor closed,
  BitmapDescriptor selected,
});

Future<MapPinIcons> loadMapPinIcons() async {
  final data = await rootBundle.load('assets/brand/mark.png');
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: 256,
  );
  final logo = (await codec.getNextFrame()).image;
  final icons = await Future.wait([
    _createPinIcon(logo, AppColors.green, selected: false),
    _createPinIcon(logo, AppColors.neutral, selected: false),
    _createPinIcon(logo, AppColors.accent, selected: true),
  ]);
  logo.dispose();
  codec.dispose();
  return (open: icons[0], closed: icons[1], selected: icons[2]);
}

Future<BitmapDescriptor> _createPinIcon(
  ui.Image logo,
  Color borderColor, {
  required bool selected,
}) async {
  const pixelRatio = 2.0;
  final logicalWidth = selected ? 52.0 : 44.0;
  final logicalHeight = selected ? 64.0 : 54.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  final center = Offset(logicalWidth / 2, logicalWidth / 2);
  final radius = selected ? 21.5 : 18.5;
  final strokeWidth = selected ? 3.5 : 3.0;

  final tail = Path()
    ..moveTo(center.dx - 7, center.dy + radius - 3)
    ..lineTo(center.dx + 7, center.dy + radius - 3)
    ..lineTo(center.dx, logicalHeight - 2)
    ..close();
  canvas.drawShadow(tail, Colors.black, 5, true);
  canvas.drawPath(tail, Paint()..color = borderColor);

  final badge = Path()
    ..addOval(Rect.fromCircle(center: center, radius: radius + strokeWidth));
  canvas.drawShadow(badge, Colors.black, 5, true);
  canvas.drawCircle(center, radius + strokeWidth, Paint()..color = borderColor);
  canvas.drawCircle(center, radius, Paint()..color = Colors.white);

  final logoRect = Rect.fromCircle(center: center, radius: radius * 0.58);
  canvas.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    logoRect,
    Paint()..filterQuality = FilterQuality.high,
  );

  final image = await recorder.endRecording().toImage(
    (logicalWidth * pixelRatio).round(),
    (logicalHeight * pixelRatio).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) throw StateError('Could not render map pin');
  return BitmapDescriptor.bytes(
    bytes.buffer.asUint8List(),
    imagePixelRatio: pixelRatio,
  );
}
