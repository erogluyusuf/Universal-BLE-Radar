import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class RadarPainter extends CustomPainter {
  final List<ScanResult> scanResults;
  final Animation<double> animation;

  RadarPainter({required this.scanResults, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // 1. Radar Halkalarını Çiz (Yeşil ve silik)
    final circlePaint = Paint()
      ..color = const Color(0xFF00FF00).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), circlePaint);
    }

    // 2. Tarama Çizgisini Çiz (Dönen ibre)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: pi * 2,
        colors: [
          Colors.transparent,
          const Color(0xFF00FF00).withOpacity(0.5),
        ],
        stops: const [0.7, 1.0],
        transform: GradientRotation(animation.value * pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, Paint()..shader = sweepPaint.shader);

    // 3. Cihazları (Noktaları) Çiz
    final devicePaint = Paint()..style = PaintingStyle.fill;

    for (var result in scanResults) {
      // RSSI değerini mesafeye çevir (Basit bir oranlama)
      // -100 dBm (Uzak) -> 1.0 (Dış halka)
      // -30 dBm (Yakın) -> 0.0 (Merkez)
      double distanceFactor = ((result.rssi.abs() - 30) / 70).clamp(0.0, 1.0);
      
      // Rastgele bir açı ata (Cihazın gerçek yönünü bilemeyiz, sadece mesafeyi biliriz)
      // Sabit kalması için cihaz ID'sinin hash'ini kullanıyoruz
      final angle = (result.device.remoteId.str.hashCode % 360) * (pi / 180);

      final deviceX = center.dx + (radius * distanceFactor) * cos(angle);
      final deviceY = center.dy + (radius * distanceFactor) * sin(angle);

      // Cihazın rengini ayarla (İsimliyse Mavi, değilse Kırmızı)
      devicePaint.color = result.device.platformName.isNotEmpty 
          ? Colors.cyanAccent 
          : Colors.redAccent;

      canvas.drawCircle(Offset(deviceX, deviceY), 6, devicePaint);
    }
    
    // 4. Merkezi (Sen) Çiz
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
