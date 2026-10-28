import 'package:nexora/src/utils/serial_task_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps Android's process eligible to run while a user-started P2P session is active.
/// Other platforms retain the session without a native background entitlement.
class BackgroundConnectionService {
  BackgroundConnectionService({MethodChannel? channel, bool? android})
    : _channel = channel ?? const MethodChannel('nexora/background_connection'),
      _android =
          android ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  final MethodChannel _channel;
  final bool _android;
  bool _active = false;
  final _tasks = SerialTaskQueue();

  Future<void> start() => _tasks.run(() async {
    if (_active) return;
    if (_android && await _channel.invokeMethod<bool>('start') != true) {
      throw StateError('Não foi possível ativar a conexão em segundo plano.');
    }
    _active = true;
  });

  Future<void> stop() => _tasks.run(() async {
    if (!_active) return;
    if (_android) await _channel.invokeMethod<void>('stop');
    _active = false;
  });
}
