import 'dart:convert';

import 'package:nexora/src/models/community_room.dart';
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
      if (group.isCommunity) ...{
        'community': true,
        'channels': group.channels,
        'roomChanges': group.roomChanges
            .map((change) => change.toMap())
            .toList(),
      },
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
    final isCommunity = payload['community'] == true;
    final groupId = payload['id'];
    final validId =
        groupId is String &&
        (RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(groupId) ||
            (isCommunity && RegExp(r'^comm_[0-9]+_[0-9]+$').hasMatch(groupId)));
    if (payload['type'] != 'nexora-group-v1' ||
        !validId ||
        !members.contains(creator) ||
        !members.contains(user.currentUser.id) ||
        members.toSet().length != members.length ||
        (!isCommunity && members.length < 3) ||
        members.any(user.isBlocked))
      throw const FormatException('Convite de grupo invalido.');
    final channels = isCommunity
        ? (payload['channels'] as List? ?? const [])
              .cast<String>()
              .map(
                (name) => CommunityRoomChange.normalizeName(name, voice: false),
              )
              .where((name) => name.isNotEmpty && name.length <= 32)
              .toSet()
              .toList()
        : null;
    final roomChanges = <String, CommunityRoomChange>{};
    if (isCommunity) {
      for (final entry in payload['roomChanges'] as List? ?? const []) {
        final change = CommunityRoomChange.fromMap(
          entry as Map<String, dynamic>,
        );
        if (!members.contains(change.author) ||
            change.author == user.currentUser.id)
          continue;
        final existing = roomChanges[change.id];
        if (existing == null || change.replaces(existing))
          roomChanges[change.id] = change;
      }
    }
    return user.createConversation(
      title: payload['title'] as String,
      participantIds: members,
      isGroup: true,
      groupId: groupId,
      communityChannels: channels,
      communityRoomChanges: roomChanges.values.toList(),
    );
  }
}
