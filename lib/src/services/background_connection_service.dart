import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/utils/serial_task_queue.dart';

/// Each conversation holds a lease on Android's shared foreground service.
class BackgroundConnectionService {
  BackgroundConnectionService({MethodChannel? channel, bool? android})
    : _service = channel == null ? _sharedService : _ForegroundService(channel),
      _android = android ?? (defaultTargetPlatform == TargetPlatform.android);

  static final _sharedService = _ForegroundService(
    const MethodChannel('nexora/background_connection'),
  );

  final _ForegroundService _service;
  final bool _android;

  Future<void> start() async {
    if (_android) await _service.acquire(this);
  }

  Future<void> stop() async {
    if (_android) await _service.release(this);
  }
}

class _ForegroundService {
  _ForegroundService(this._channel);

  final MethodChannel _channel;
  final _tasks = SerialTaskQueue();
  final _owners = <BackgroundConnectionService>{};

  Future<void> acquire(
    BackgroundConnectionService owner,
  ) => _tasks.run(() async {
    if (_owners.contains(owner)) return;
    if (_owners.isEmpty && await _channel.invokeMethod<bool>('start') != true) {
      throw StateError('Não foi possível ativar a conexão em segundo plano.');
    }
    _owners.add(owner);
  });

  Future<void> release(BackgroundConnectionService owner) =>
      _tasks.run(() async {
        if (!_owners.contains(owner)) return;
        if (_owners.length == 1) await _channel.invokeMethod<void>('stop');
        _owners.remove(owner);
      });
}
