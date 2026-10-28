import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/services/message_service.dart';
import 'package:nexora/src/services/p2p_connection_service.dart';

/// A group is a full mesh: no participant forwards another author's messages.
class ConversationConnectionService extends ChangeNotifier {
  ConversationConnectionService({
    required this.conversation,
    required this.localUserId,
    required int connectionTimeoutSeconds,
    P2PConnectionService Function(String key)? createPeer,
  }) {
    for (final key in conversation.participantIds.where(
      (id) => id != localUserId,
    )) {
      final peer =
          createPeer?.call(key) ??
          P2PConnectionService(
            conversationId: conversation.id,
            localUserId: localUserId,
            remotePublicKey: key,
            connectionTimeoutSeconds: connectionTimeoutSeconds,
          );
      _peers[key] = peer;
      peer.addListener(_changed);
      _subscriptions.add(
        peer.messages.listen(
          (message) => _receive(key, message),
          onError: _messages.addError,
        ),
      );
    }
    _selected = _peers.keys.first;
  }
  final Conversation conversation;
  final String localUserId;
  final _peers = <String, P2PConnectionService>{};
  final _subscriptions = <StreamSubscription<DecryptedMessage>>[];
  final _messages = StreamController<DecryptedMessage>.broadcast();
  late String _selected;
  int _id = DateTime.now().microsecondsSinceEpoch;
  bool _closed = false;
  static const _prefix = 'NEXORA_GROUP_V1:';
  String get _membership =>
      (List<String>.from(conversation.participantIds)..sort()).join(',');
  Stream<DecryptedMessage> get messages => _messages.stream;
  String get remotePublicKey => _selected;
  List<String> get peerKeys => _peers.keys.toList();
  P2PConnectionService get _peer => _peers[_selected]!;
  int get connectedCount =>
      _peers.values.where((peer) => peer.isConnected).length;
  bool get isConnected => _peers.values.every((peer) => peer.isConnected);
  bool get canApplyAnswer => _peer.canApplyAnswer;
  P2PConnectionStatus get status =>
      conversation.isGroup && connectedCount > 0 && !isConnected
      ? P2PConnectionStatus.connecting
      : _peer.status;
  bool peerConnected(String key) => _peers[key]!.isConnected;
  void selectPeer(String key) {
    if (!_peers.containsKey(key)) throw ArgumentError('Participante invalido.');
    _selected = key;
    notifyListeners();
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<String> createOffer() => _peer.createOffer();
  Future<String> acceptOffer(String text) => _peer.acceptOffer(text);
  Future<void> acceptAnswer(String text) => _peer.acceptAnswer(text);
  void _emit(String sender, String content, DateTime sentAt) {
    if (!_closed)
      _messages.add(
        DecryptedMessage(
          id: '${++_id}',
          conversationId: conversation.id,
          senderId: sender,
          content: content,
          sentAt: sentAt,
        ),
      );
  }

  void _receive(String peer, DecryptedMessage message) {
    if (!conversation.isGroup) {
      _emit(message.senderId, message.content, message.sentAt);
      return;
    }
    if (message.senderId != peer || !message.content.startsWith(_prefix))
      return;
    try {
      final body = jsonDecode(
        message.content.substring(_prefix.length),
      ) as Map<String, dynamic>;
      if (body['group'] != conversation.id ||
          body['members'] != _membership ||
          body['text'] is! String)
        return;
      _emit(peer, body['text'] as String, message.sentAt);
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (!conversation.isGroup) {
      await _peer.sendMessage(text);
      return;
    }
    if (!isConnected)
      throw StateError('Conecte todos os participantes antes de enviar.');
    final content = text.trim();
    if (content.isEmpty) throw ArgumentError('Mensagem vazia.');
    final frame =
        '$_prefix${jsonEncode({'group': conversation.id, 'members': _membership, 'text': content})}';
    await Future.wait(_peers.values.map((peer) => peer.sendMessage(frame)));
    _emit(localUserId, content, DateTime.now().toUtc());
  }

  Future<void> disconnect() =>
      Future.wait(_peers.values.map((peer) => peer.disconnect()));
  Future<void> close() async {
    _closed = true;
    for (final peer in _peers.values) {
      peer.removeListener(_changed);
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await Future.wait(_peers.values.map((peer) => peer.close()));
    await _messages.close();
  }
}
