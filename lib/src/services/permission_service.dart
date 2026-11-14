import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:nexora/src/utils/serial_task_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class PlatformPermissionsState {
  const PlatformPermissionsState({
    required this.camera,
    required this.microphone,
    required this.notifications,
    required this.bluetooth,
    required this.requestedOnFirstLaunch,
    this.updatedAt,
  });

  static const initial = PlatformPermissionsState(
    camera: false,
    microphone: false,
    notifications: false,
    bluetooth: false,
    requestedOnFirstLaunch: false,
  );

  final bool camera;
  final bool microphone;
  final bool notifications;
  final bool bluetooth;
  final bool requestedOnFirstLaunch;
  final DateTime? updatedAt;

  bool get allGranted => camera && microphone && notifications && bluetooth;

  PlatformPermissionsState copyWith({
    bool? camera,
    bool? microphone,
    bool? notifications,
    bool? bluetooth,
    bool? requestedOnFirstLaunch,
    DateTime? updatedAt,
  }) => PlatformPermissionsState(
    camera: camera ?? this.camera,
    microphone: microphone ?? this.microphone,
    notifications: notifications ?? this.notifications,
    bluetooth: bluetooth ?? this.bluetooth,
    requestedOnFirstLaunch:
        requestedOnFirstLaunch ?? this.requestedOnFirstLaunch,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'v': 1,
    'camera': camera,
    'microphone': microphone,
    'notifications': notifications,
    'bluetooth': bluetooth,
    'requestedOnFirstLaunch': requestedOnFirstLaunch,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  String toJson() => jsonEncode(toMap());

  factory PlatformPermissionsState.fromMap(Map<String, dynamic> map) =>
      PlatformPermissionsState(
        camera: map['camera'] == true,
        microphone: map['microphone'] == true,
        notifications: map['notifications'] == true,
        bluetooth: map['bluetooth'] == true,
        requestedOnFirstLaunch: map['requestedOnFirstLaunch'] == true,
        updatedAt: map['updatedAt'] is String
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null,
      );

  factory PlatformPermissionsState.fromJson(String source) =>
      PlatformPermissionsState.fromMap(
        jsonDecode(source) as Map<String, dynamic>,
      );
}

class PermissionService extends ChangeNotifier {
  PermissionService({
    MethodChannel? channel,
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _channel = channel ?? const MethodChannel('nexora/permissions'),
       _providedPreferences = preferences,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static final PermissionService instance = PermissionService();
  static const _prefsStorageKey = 'nexora.permissions.v1';
  static const _secureStorageKey = 'nexora.permissions.secure.v1';

  final MethodChannel _channel;
  final SharedPreferencesAsync? _providedPreferences;
  final FlutterSecureStorage _secureStorage;
  final _tasks = SerialTaskQueue();

  PlatformPermissionsState _state = PlatformPermissionsState.initial;
  PlatformPermissionsState get state => _state;

  SharedPreferencesAsync get _prefs =>
      _providedPreferences ?? SharedPreferencesAsync();

  bool get _usesNativePermissionChannel =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<PlatformPermissionsState?> _readFromStorage() async {
    try {
      final rawPrefs = await _prefs.getString(_prefsStorageKey);
      if (rawPrefs != null && rawPrefs.isNotEmpty) {
        return PlatformPermissionsState.fromJson(rawPrefs);
      }
    } catch (_) {}
    try {
      final rawSecure = await _secureStorage.read(key: _secureStorageKey);
      if (rawSecure != null && rawSecure.isNotEmpty) {
        return PlatformPermissionsState.fromJson(rawSecure);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeToStorage(PlatformPermissionsState nextState) async {
    final serialized = nextState.toJson();
    try {
      await _prefs.setString(_prefsStorageKey, serialized);
    } catch (_) {}
    try {
      await _secureStorage.write(key: _secureStorageKey, value: serialized);
    } catch (_) {}
  }

  Future<void> _stopStream(MediaStream? stream) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
  }

  Future<Map<String, bool>> _requestFallbackMediaPermissions() async {
    bool microphone = _state.microphone;
    bool camera = _state.camera;
    MediaStream? audioStream;
    try {
      audioStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      microphone = true;
    } catch (_) {
      microphone = false;
    } finally {
      await _stopStream(audioStream);
    }

    MediaStream? videoStream;
    try {
      videoStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': true,
      });
      camera = true;
    } catch (_) {
      camera = false;
    } finally {
      await _stopStream(videoStream);
    }

    return {
      'camera': camera,
      'microphone': microphone,
      'notifications': true,
      'bluetooth': true,
    };
  }

  Future<Map<String, bool>?> _invokeNative(String method) async {
    if (!_usesNativePermissionChannel) return null;
    try {
      final response = await _channel.invokeMapMethod<String, bool>(method);
      return response;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  PlatformPermissionsState _mergePermissions(
    PlatformPermissionsState base,
    Map<String, bool> granted, {
    required bool requestedOnFirstLaunch,
  }) => base.copyWith(
    camera: granted['camera'] ?? base.camera,
    microphone: granted['microphone'] ?? base.microphone,
    notifications: granted['notifications'] ?? base.notifications,
    bluetooth: granted['bluetooth'] ?? base.bluetooth,
    requestedOnFirstLaunch: requestedOnFirstLaunch,
    updatedAt: DateTime.now(),
  );

  /// Loads stored permissions and, on the very first launch of the app,
  /// requests the system-level permissions declared in the platform manifests
  /// and persists the result in the device's storage.
  Future<PlatformPermissionsState> initializeAndRequestOnFirstLaunch() =>
      _tasks.run(() async {
        final stored = await _readFromStorage();
        if (stored != null) {
          _state = stored;
          notifyListeners();
        }

        if (stored == null || !stored.requestedOnFirstLaunch) {
          final granted =
              await _invokeNative('request') ??
              await _requestFallbackMediaPermissions();
          _state = _mergePermissions(
            _state,
            granted,
            requestedOnFirstLaunch: true,
          );
          await _writeToStorage(_state);
          notifyListeners();
          return _state;
        }

        final checked = await _invokeNative('check');
        if (checked != null) {
          _state = _mergePermissions(
            _state,
            checked,
            requestedOnFirstLaunch: true,
          );
          await _writeToStorage(_state);
          notifyListeners();
        }
        return _state;
      });

  /// Explicitly requests system-level permissions again and updates device storage.
  Future<PlatformPermissionsState> requestPermissions() => _tasks.run(() async {
    final granted =
        await _invokeNative('request') ??
        await _requestFallbackMediaPermissions();
    _state = _mergePermissions(
      _state,
      granted,
      requestedOnFirstLaunch: true,
    );
    await _writeToStorage(_state);
    notifyListeners();
    return _state;
  });

  /// Refreshes the current system-level permission state and saves to device storage.
  Future<PlatformPermissionsState> refreshPermissions() => _tasks.run(() async {
    final checked = await _invokeNative('check');
    if (checked != null) {
      _state = _mergePermissions(
        _state,
        checked,
        requestedOnFirstLaunch: _state.requestedOnFirstLaunch,
      );
      await _writeToStorage(_state);
      notifyListeners();
    }
    return _state;
  });
}
