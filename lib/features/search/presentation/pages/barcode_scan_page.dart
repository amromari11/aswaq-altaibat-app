import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Full-screen barcode scanner. Pops with the scanned (or typed) code; the
/// caller searches the catalog for it (the POS barcode is the product SKU).
///
/// Typing the number is always offered: it is the way in on a device without a
/// camera, and a fallback when a label is too worn to scan.
class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key, this.cameraBuilder});

  /// Replaces the live camera view (tests, or platforms without a camera).
  final Widget Function(void Function(String code) onCode)? cameraBuilder;

  static const manualFieldKey = ValueKey('scan-manual-field');
  static const manualSubmitKey = ValueKey('scan-manual-submit');

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final _manual = TextEditingController();
  MobileScannerController? _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.cameraBuilder == null) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.qrCode,
        ],
      );
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _finish(String code) {
    final clean = code.trim();
    if (_done || clean.isEmpty) return;
    _done = true;
    context.pop(clean);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح الباركود'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.cameraBuilder != null)
                  widget.cameraBuilder!(_finish)
                else
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final value = barcode.rawValue;
                        if (value != null && value.isNotEmpty) return _finish(value);
                      }
                    },
                    errorBuilder: (context, error) => const _CameraUnavailable(),
                  ),
                // Only a frame to aim with: it must not swallow taps meant for the camera view.
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Text(
                    'وجّه الكاميرا نحو الباركود',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: BarcodeScanPage.manualFieldKey,
                    controller: _manual,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _finish,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(hintText: 'أو اكتب رقم الباركود'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  key: BarcodeScanPage.manualSubmitKey,
                  onPressed: () => _finish(_manual.text),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: const Text('بحث'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              'تعذر فتح الكاميرا. اسمح بالوصول إلى الكاميرا، أو اكتب رقم الباركود في الأسفل.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.border),
            ),
          ],
        ),
      ),
    );
  }
}
