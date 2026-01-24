import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/constants.dart';
import '../services/qr_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  
  final QRService _qrService = QRService();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null) {
        final eventCode = _qrService.parseQRData(rawValue);
        if (eventCode != null) {
          _hasScanned = true;
          Navigator.of(context).pop(eventCode);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanAreaSize = 250.0;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay with scanning area
          CustomPaint(
            painter: _ScannerOverlayPainter(
              scanAreaSize: scanAreaSize,
              screenSize: screenSize,
            ),
          ),

          // Scanning area border
          Center(
            child: Container(
              width: scanAreaSize,
              height: scanAreaSize,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Stack(
                children: [
                  // Corner decorations
                  Positioned(
                    top: -2,
                    left: -2,
                    child: _buildCorner(true, true),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: _buildCorner(true, false),
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: _buildCorner(false, true),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: _buildCorner(false, false),
                  ),
                ],
              ),
            ),
          ),

          // Top controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildControlButton(
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildControlButton(
                  icon: Icons.flash_on,
                  onPressed: () => _controller.toggleTorch(),
                ),
              ],
            ),
          ),

          // Instructions
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Scan QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Point your camera at a SnapNest QR code',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: AppColors.accent, width: 5)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: AppColors.accent, width: 5)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: AppColors.accent, width: 5)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: AppColors.accent, width: 5)
              : BorderSide.none,
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final Size screenSize;

  _ScannerOverlayPainter({
    required this.scanAreaSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final scanAreaRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    // Draw overlay with hole for scan area
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              scanAreaRect,
              const Radius.circular(AppRadius.lg),
            ),
          ),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
