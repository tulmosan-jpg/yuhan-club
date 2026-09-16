import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 전자서명 패드.
///
/// 손가락 획을 모아 그리고, [SignaturePadController.toPngBytes] 로
/// 흰 배경 PNG 를 뽑는다(엑셀·문서에 붙여도 보이도록 투명 배경을 쓰지 않는다).
/// 외부 패키지 없이 CustomPainter 로 구현.
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _lastSize = Size.zero;

  bool get isEmpty => _strokes.isEmpty;

  void _start(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void _extend(Offset p) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(p);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// 현재 서명을 흰 배경 PNG 바이트로 렌더링. 비어 있으면 null.
  Future<Uint8List?> toPngBytes({double scale = 2}) async {
    if (_strokes.isEmpty || _lastSize == Size.zero) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawRect(
      Offset.zero & _lastSize,
      Paint()..color = Colors.white,
    );
    _SignaturePainter(_strokes).paint(canvas, _lastSize);
    final image = await recorder.endRecording().toImage(
          (_lastSize.width * scale).round(),
          (_lastSize.height * scale).round(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller});

  final SignaturePadController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        controller._lastSize =
            Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => controller._start(d.localPosition),
          onPanUpdate: (d) => controller._extend(d.localPosition),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SignaturePainter(controller._strokes),
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF18181B)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        // 중간점 보간으로 부드러운 곡선.
        final prev = stroke[i - 1];
        final cur = stroke[i];
        final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
