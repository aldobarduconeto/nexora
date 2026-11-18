import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart'
    show BinaryBitmap, HybridBinarizer, QRCodeReader, RGBLuminanceSource;

String _readQrImage(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Imagem inválida.');

  final pixels = decoded
      .convert(numChannels: 4)
      .getBytes(order: image.ChannelOrder.rgba);
  final source = RGBLuminanceSource(
    decoded.width,
    decoded.height,
    pixels.buffer.asInt32List(pixels.offsetInBytes, pixels.length ~/ 4),
  );
  return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
}

class MirrorQrActions extends StatelessWidget {
  const MirrorQrActions({super.key, required this.onCode});

  final ValueChanged<String>? onCode;

  Future<void> _scan(BuildContext context) async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _MirrorQrScanner()));
    if (context.mounted && code != null) onCode?.call(code);
  }

  Future<void> _openImage(BuildContext context) async {
    String code;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null || !context.mounted) return;
      code = await compute(_readQrImage, await file.readAsBytes());
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível ler o QR Code da imagem.'),
          ),
        );
      }
      return;
    }
    if (context.mounted) onCode?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    final hasCameraScanner =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasCameraScanner)
          OutlinedButton.icon(
            onPressed: onCode == null ? null : () => _scan(context),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Escanear QR Code'),
          ),
        OutlinedButton.icon(
          onPressed: onCode == null ? null : () => _openImage(context),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Abrir imagem do QR Code'),
        ),
      ],
    );
  }
}

class _MirrorQrScanner extends StatefulWidget {
  const _MirrorQrScanner();

  @override
  State<_MirrorQrScanner> createState() => _MirrorQrScannerState();
}

class _MirrorQrScannerState extends State<_MirrorQrScanner> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected || ModalRoute.of(context)?.isCurrent != true) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      _detected = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR Code')),
    body: MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (_, _) => const Center(
        child: Text(
          'Câmera indisponível. Volte para usar uma imagem ou digitar o código.',
        ),
      ),
    ),
  );
}
