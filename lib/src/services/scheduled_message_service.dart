import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nexora/src/models/scheduled_message.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço responsável pelo gerenciamento, persistência e disparo
/// de mensagens agendadas para envio futuro no Nexora.
class ScheduledMessageService extends ChangeNotifier {
  ScheduledMessageService({SharedPreferencesAsync? preferences})
      : _providedPreferences = preferences {
    _startTimer();
  }

  static final ScheduledMessageService instance = ScheduledMessageService();
  static const _storageKey = 'nexora.scheduled_messages.v1';

  final SharedPreferencesAsync? _providedPreferences;
  SharedPreferencesAsync get _prefs =>
      _providedPreferences ?? SharedPreferencesAsync();

  final List<ScheduledMessage> _messages = [];
  Timer? _ticker;

  final StreamController<ScheduledMessage> _dueMessagesController =
      StreamController<ScheduledMessage>.broadcast();

  /// Stream que emite mensagens cujo horário agendado foi atingido.
  Stream<ScheduledMessage> get onDueMessage => _dueMessagesController.stream;

  /// Retorna cópia não-modificável de todas as mensagens agendadas.
  List<ScheduledMessage> get allMessages => List.unmodifiable(_messages);

  /// Retorna as mensagens agendadas para uma conversa específica ordenadas por horário.
  List<ScheduledMessage> getMessagesForConversation(String conversationId) {
    final list = _messages
        .where((m) => m.conversationId == conversationId)
        .toList();
    list.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return list;
  }

  /// Carrega as mensagens salvas no disco.
  Future<void> load() async {
    try {
      final raw = await _prefs.getString(_storageKey);
      _messages.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _messages.add(ScheduledMessage.fromMap(item));
            } else if (item is Map) {
              _messages.add(ScheduledMessage.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar mensagens agendadas: $e');
    }
  }

  Future<void> _save() async {
    try {
      final list = _messages.map((m) => m.toMap()).toList();
      await _prefs.setString(_storageKey, jsonEncode(list));
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao salvar mensagens agendadas: $e');
    }
  }

  /// Agenda uma nova mensagem.
  Future<void> scheduleMessage(ScheduledMessage message) async {
    _messages.removeWhere((m) => m.id == message.id);
    _messages.add(message);
    await _save();
  }

  /// Cancela o agendamento de uma mensagem.
  Future<void> cancelMessage(String id) async {
    final initialCount = _messages.length;
    _messages.removeWhere((m) => m.id == id);
    if (_messages.length != initialCount) {
      await _save();
    }
  }

  /// Altera o horário agendado de uma mensagem.
  Future<void> rescheduleMessage(String id, DateTime newTime) async {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(scheduledFor: newTime);
      await _save();
    }
  }

  /// Marca uma mensagem agendada como enviada/concluída, removendo-a da fila.
  Future<void> markAsSent(String id) async {
    await cancelMessage(id);
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _checkDueMessages());
  }

  void _checkDueMessages() {
    if (_messages.isEmpty) return;
    final now = DateTime.now();
    final due = _messages.where((m) => !m.scheduledFor.isAfter(now)).toList();

    for (final message in due) {
      _dueMessagesController.add(message);

      // Notificação se habilitada
      final s = SettingsService.instance.settings;
      if (s.scheduledMessagesNotification && s.notificationsEnabled) {
        NotificationService.instance.pushNotification(
          PushNotificationItem(
            id: 'sched_${message.id}',
            title: '🕒 Mensagem Agendada',
            body: 'A mensagem agendada está pronta para envio: "${message.content}"',
            type: NotificationType.message,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dueMessagesController.close();
    super.dispose();
  }
}
