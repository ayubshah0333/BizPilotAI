import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/theme.dart';

class CameraBarcodeScanner extends StatefulWidget {
  final ValueChanged<String> onScanned;

  const CameraBarcodeScanner({
    super.key,
    required this.onScanned,
  });

  static Future<String?> scan(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CameraBarcodeScanner(
        onScanned: (code) => Navigator.pop(ctx, code),
      ),
    );
  }

  @override
  State<CameraBarcodeScanner> createState() => _CameraBarcodeScannerState();
}

class _CameraBarcodeScannerState extends State<CameraBarcodeScanner> {
  late MobileScannerController _controller;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanned) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _isScanned = true;
                  widget.onScanned(rawValue);
                  break;
                }
              }
            },
          ),

          // Viewfinder Cutout Overlay
          Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.indigoLight, width: 2.5),
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: Stack(
                children: [
                  // Corner Highlights
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cyanAccent, width: 4), left: BorderSide(color: AppColors.cyanAccent, width: 4)))),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cyanAccent, width: 4), right: BorderSide(color: AppColors.cyanAccent, width: 4)))),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cyanAccent, width: 4), left: BorderSide(color: AppColors.cyanAccent, width: 4)))),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cyanAccent, width: 4), right: BorderSide(color: AppColors.cyanAccent, width: 4)))),
                  ),
                  const Center(
                    child: Text(
                      'Point camera at Barcode / QR',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Header Controls
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Barcode & QR Scanner',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      onPressed: () => _controller.toggleTorch(),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
