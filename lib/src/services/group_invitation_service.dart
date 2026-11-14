import 'dart:convert';

import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/services/identity_protocol.dart';
import 'package:nexora/src/services/local_data_service.dart';

abstract final class GroupInvitationService {
  static Future<String> export(Conversation group, LocalDataService user) {
    if (!group.isGroup || !group.participantIds.contains(user.currentUser.id))
      throw ArgumentError('Grupo invalido.');
    return IdentityProtocol.sign({
      'type': 'nexora-group-v1',
      'identity': user.currentUser.id,
      'id': group.id,
      'title': group.title,
      'members': group.participantIds,
    }, user.identityKeyPair);
  }

  static Future<Conversation> import(String text, LocalDataService user) async {
    if (text.length > 128 * 1024)
      throw const FormatException('Convite muito grande.');
    final envelope = jsonDecode(text) as Map<String, dynamic>;
    final creator = IdentityProtocol.normalize(
      (envelope['payload'] as Map<String, dynamic>)['identity'] as String,
    );
    final payload = await IdentityProtocol.verify(text, creator);
    final members = (payload['members'] as List)
        .map((key) => IdentityProtocol.normalize(key as String))
        .toList();
    if (payload['type'] != 'nexora-group-v1' ||
        payload['id'] is! String ||
        !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(payload['id'] as String) ||
        !members.contains(creator) ||
        !members.contains(user.currentUser.id) ||
        members.toSet().length != members.length ||
        members.length < 3 ||
        members.any(user.isBlocked))
      throw const FormatException('Convite de grupo invalido.');
    return user.createConversation(
      title: payload['title'] as String,
      participantIds: members,
      isGroup: true,
      groupId: payload['id'] as String,
    );
  }
}
