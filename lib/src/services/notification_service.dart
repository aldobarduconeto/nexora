import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/utils/serial_task_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationType { message, call, file, mirror, security, system }

@immutable
class PushNotificationItem {
  const PushNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.conversationId,
    this.senderKey,
    this.senderName,
    this.payload,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final String? conversationId;
  final String? senderKey;
  final String? senderName;
  final String? payload;
  final bool isRead;

  PushNotificationItem copyWith({bool? isRead}) => PushNotificationItem(
    id: id,
    title: title,
    body: body,
    type: type,
    createdAt: createdAt,
    conversationId: conversationId,
    senderKey: senderKey,
    senderName: senderName,
    payload: payload,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'conversationId': conversationId,
    'senderKey': senderKey,
    'senderName': senderName,
    'payload': payload,
    'isRead': isRead,
  };

  factory PushNotificationItem.fromMap(Map<String, dynamic> map) =>
      PushNotificationItem(
        id: map['id'] as String? ?? UniqueKey().toString(),
        title: map['title'] as String? ?? 'Nexora',
        body: map['body'] as String? ?? '',
        type: NotificationType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => NotificationType.system,
        ),
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        conversationId: map['conversationId'] as String?,
        senderKey: map['senderKey'] as String?,
        senderName: map['senderName'] as String?,
        payload: map['payload'] as String?,
        isRead: map['isRead'] as bool? ?? false,
      );

  String toJson() => jsonEncode(toMap());
}

class NotificationService extends ChangeNotifier {
  NotificationService({
    MethodChannel? channel,
    SharedPreferencesAsync? preferences,
  }) : _channel = channel ?? const MethodChannel('nexora/notifications'),
       _providedPreferences = preferences;

  static final NotificationService instance = NotificationService();
  static const _storageKey = 'nexora.notifications_history.v1';

  final MethodChannel _channel;
  final SharedPreferencesAsync? _providedPreferences;
  final _tasks = SerialTaskQueue();

  SharedPreferencesAsync get _prefs =>
      _providedPreferences ?? SharedPreferencesAsync();

  final List<PushNotificationItem> _history = [];
  List<PushNotificationItem> get history => List.unmodifiable(_history);

  final _streamController = StreamController<PushNotificationItem>.broadcast();
  Stream<PushNotificationItem> get onNotificationPushed =>
      _streamController.stream;

  final ValueNotifier<PushNotificationItem?> activeBanner =
      ValueNotifier<PushNotificationItem?>(null);

  Timer? _bannerDismissTimer;

  Future<void> initialize() => _tasks.run(() async {
    try {
      final raw = await _prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _history.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _history.add(PushNotificationItem.fromMap(item));
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  });

  Future<void> _saveHistory() async {
    try {
      final trimmed = _history.take(60).map((n) => n.toMap()).toList();
      await _prefs.setString(_storageKey, jsonEncode(trimmed));
    } catch (_) {}
  }

  /// Pushes a notification to both the in-app interactive heads-up banner
  /// and the operating system notification center (Windows, Linux, macOS, Android, iOS).
  Future<void> pushNotification(PushNotificationItem item) =>
      _tasks.run(() async {
        final settings = SettingsService.instance.settings;
        if (!settings.notificationsEnabled) return;

        // Apply message preview setting
        String finalBody = item.body;
        if (!settings.notificationPreview &&
            (item.type == NotificationType.message ||
                item.type == NotificationType.file)) {
          finalBody = 'Nova mensagem criptografada recebida.';
        }

        final finalItem = PushNotificationItem(
          id: item.id,
          title: item.title,
          body: finalBody,
          type: item.type,
          createdAt: item.createdAt,
          conversationId: item.conversationId,
          senderKey: item.senderKey,
          senderName: item.senderName,
          payload: item.payload,
          isRead: false,
        );

        // Add to history
        _history.insert(0, finalItem);
        if (_history.length > 80) _history.removeLast();
        await _saveHistory();
        notifyListeners();
        _streamController.add(finalItem);

        // Show interactive In-App Heads-Up Banner
        activeBanner.value = finalItem;
        _bannerDismissTimer?.cancel();
        _bannerDismissTimer = Timer(const Duration(seconds: 4), () {
          if (activeBanner.value?.id == finalItem.id) {
            activeBanner.value = null;
          }
        });

        // Trigger native feedback
        if (settings.notificationSound) {
          try {
            await HapticFeedback.selectionClick();
            await SystemSound.play(SystemSoundType.click);
          } catch (_) {}
        }

        // Dispatch to operating system
        await _dispatchToOS(finalItem);
      });

  Future<void> _dispatchToOS(PushNotificationItem item) async {
    final title = item.title;
    final body = item.body;

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _channel.invokeMethod('show', {
          'id': item.id.hashCode & 0x7FFFFFFF,
          'title': title,
          'body': body,
          'payload': item.conversationId ?? item.payload ?? '',
        });
      } catch (_) {}
      return;
    }

    if (kIsWeb) return;

    // Desktop system notification integration
    try {
      if (Platform.isWindows) {
        // Safe PowerShell notification command with XML Toast template
        final escapedTitle = title.replaceAll("'", "''").replaceAll('"', '`"');
        final escapedBody = body.replaceAll("'", "''").replaceAll('"', '`"');
        final psCommand =
            "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null; "
            "\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); "
            "\$xml = \$template.GetElementsByTagName('text'); "
            "\$xml[0].AppendChild(\$template.CreateTextNode('$escapedTitle')) > \$null; "
            "\$xml[1].AppendChild(\$template.CreateTextNode('$escapedBody')) > \$null; "
            "\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template); "
            "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Nexora').Show(\$toast)";
        unawaited(
          Process.run('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            psCommand,
          ]),
        );
      } else if (Platform.isLinux) {
        unawaited(Process.run('notify-send', ['-a', 'Nexora', title, body]));
      } else if (Platform.isMacOS) {
        final escapedBody = body.replaceAll('"', '\\"');
        final escapedTitle = title.replaceAll('"', '\\"');
        final script =
            'display notification "$escapedBody" with title "Nexora" subtitle "$escapedTitle" sound name "default"';
        unawaited(Process.run('osascript', ['-e', script]));
      }
    } catch (_) {}
  }

  void dismissActiveBanner() {
    _bannerDismissTimer?.cancel();
    activeBanner.value = null;
  }

  Future<void> markAsRead(String id) => _tasks.run(() async {
    final index = _history.indexWhere((i) => i.id == id);
    if (index != -1) {
      _history[index] = _history[index].copyWith(isRead: true);
      await _saveHistory();
      notifyListeners();
    }
  });

  Future<void> markAllAsRead() => _tasks.run(() async {
    for (int i = 0; i < _history.length; i++) {
      _history[i] = _history[i].copyWith(isRead: true);
    }
    await _saveHistory();
    notifyListeners();
  });

  Future<void> clearHistory() => _tasks.run(() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  });

  // Convenience methods for domain events
  Future<void> notifyIncomingMessage({
    required String conversationTitle,
    required String conversationId,
    required String senderPublicKey,
    required String messageText,
    String? senderNickname,
    String mediaType = 'text',
    bool isGroup = false,
  }) {
    final senderLabel = senderNickname?.isNotEmpty == true
        ? senderNickname!
        : (senderPublicKey.length > 8
            ? senderPublicKey.substring(0, 8)
            : senderPublicKey);

    final title = isGroup ? '$senderLabel em $conversationTitle' : senderLabel;

    String content = messageText;
    if (mediaType == 'audio') {
      content = '🎙️ Mensagem de voz P2P';
    } else if (mediaType == 'poll') {
      content = '📊 Enquete compartilhada';
    } else if (mediaType == 'view_once') {
      content = '👁️ Mensagem de visualização única';
    }

    return pushNotification(
      PushNotificationItem(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        body: content,
        type: NotificationType.message,
        createdAt: DateTime.now(),
        conversationId: conversationId,
        senderKey: senderPublicKey,
        senderName: senderLabel,
      ),
    );
  }

  Future<void> notifyIncomingCall({
    required String callerName,
    required String conversationId,
    required bool isVideo,
  }) {
    return pushNotification(
      PushNotificationItem(
        id: 'call_${DateTime.now().microsecondsSinceEpoch}',
        title: isVideo ? '📹 Chamada de Vídeo' : '📞 Chamada de Voz',
        body: '$callerName está ligando para você via conexão direta.',
        type: NotificationType.call,
        createdAt: DateTime.now(),
        conversationId: conversationId,
        senderName: callerName,
      ),
    );
  }

  Future<void> notifyFileReceived({
    required String fileName,
    required String conversationId,
    String? senderName,
  }) {
    return pushNotification(
      PushNotificationItem(
        id: 'file_${DateTime.now().microsecondsSinceEpoch}',
        title: '📎 Arquivo Recebido',
        body: '${senderName ?? "Contato"} enviou: $fileName',
        type: NotificationType.file,
        createdAt: DateTime.now(),
        conversationId: conversationId,
        senderName: senderName,
      ),
    );
  }

  Future<void> notifyDeviceMirrorRequest({
    required String deviceName,
    required String deviceId,
  }) {
    return pushNotification(
      PushNotificationItem(
        id: 'mirror_${DateTime.now().microsecondsSinceEpoch}',
        title: '📱 Pedido de Pareamento',
        body: 'O dispositivo "$deviceName" solicitou espelhar esta conta.',
        type: NotificationType.mirror,
        createdAt: DateTime.now(),
        payload: deviceId,
      ),
    );
  }

  Future<void> notifyWelcome() {
    return pushNotification(
      PushNotificationItem(
        id: 'welcome_${DateTime.now().microsecondsSinceEpoch}',
        title: '🎉 Bem-vindo ao Nexora!',
        body:
            'Notificações push ativadas com sucesso. Você receberá alertas em tempo real.',
        type: NotificationType.system,
        createdAt: DateTime.now(),
      ),
    );
  }
}
