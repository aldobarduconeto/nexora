import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform channel bridge for frameless window management on desktop (Windows, macOS, Linux).
/// Falls back silently on unsupported platforms (Web, Android, iOS).
class WindowService {
  WindowService._();
  static final WindowService instance = WindowService._();

  static const MethodChannel _channel = MethodChannel('nexora/window');

  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  bool _isMaximized = false;
  bool get isMaximized => _isMaximized;

  Future<void> minimize() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('minimize');
    } catch (_) {}
  }

  Future<void> toggleMaximize() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('maximize');
      _isMaximized = !_isMaximized;
    } catch (_) {}
  }

  Future<void> close() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('close');
    } catch (_) {}
  }

  Future<void> startDragging() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod('startDragging');
    } catch (_) {}
  }

  Future<bool> checkIsMaximized() async {
    if (!isDesktop) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isMaximized');
      _isMaximized = res ?? false;
      return _isMaximized;
    } catch (_) {
      return false;
    }
  }
}
