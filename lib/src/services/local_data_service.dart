import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/models/message.dart';
import 'package:nexora/src/models/mirrored_device.dart';
import 'package:nexora/src/models/user.dart';
import 'package:nexora/src/services/identity_protocol.dart';
import 'package:nexora/src/utils/serial_task_queue.dart';
import 'package:uuid/uuid.dart';

class LocalDataService extends ChangeNotifier {
  LocalDataService({
    User? initialUser,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage,
       _currentUser = initialUser ?? _createLocalUser(nickname: '');

  static final LocalDataService instance = LocalDataService();
  static const _accountStorageKey = 'nexora.account.v2';
  static const _mirroredDevicesStorageKey = 'nexora.mirrored_devices.v1';
  static final Ed25519 _ed25519 = Ed25519();

  User _currentUser;
  SimpleKeyPair? _identity;
  List<MirroredDevice> _mirroredDevices = const [];
  final _tasks = SerialTaskQueue();
  final FlutterSecureStorage _storage;

  List<MirroredDevice> get mirroredDevices => _mirroredDevices;

  bool isBlocked(String publicKey) =>
      _currentUser.blockedUserIds.contains(publicKey);

  Future<String?> _read({required String key}) => _storage.read(key: key);

  Future<void> _write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  User get currentUser => _currentUser;
  SimpleKeyPair get identityKeyPair =>
      _identity ?? (throw StateError('Identidade não inicializada.'));

  Future<List<int>> extractPrivateSeed() async {
    return await identityKeyPair.extractPrivateKeyBytes();
  }

  Future<String> _serializeAccount(User user, SimpleKeyPair identity) async =>
      jsonEncode({
        'v': 2,
        'user': user.toMap(),
        'privateSeed': base64Encode(await identity.extractPrivateKeyBytes()),
      });

  Future<bool> restoreSession() => _tasks.run(() async {
    final serialized = await _read(key: _accountStorageKey);
    if (serialized == null) return false;
    final data = jsonDecode(serialized) as Map<String, dynamic>;
    if (data['v'] != 2) {
      throw const FormatException('Formato de conta não suportado.');
    }
    final user = User.fromMap(data['user'] as Map<String, dynamic>);
    final publicKey = IdentityProtocol.normalize(user.publicKey);
    if (user.id != publicKey) {
      throw const FormatException('Identidade inválida.');
    }
    final seed = base64Decode(data['privateSeed'] as String);
    if (seed.length != 32) {
      throw const FormatException('Chave privada inválida.');
    }
    final identity = await _ed25519.newKeyPairFromSeed(seed);
    if (base64Encode((await identity.extractPublicKey()).bytes) != publicKey) {
      throw StateError('A chave privada não corresponde à conta.');
    }
    _currentUser = user;
    _identity = identity;
    if (_owner != user.id) {
      _owner = null;
      _setConversations(const []);
    }
    await _loadMirroredDevices();
    notifyListeners();
    return true;
  });

  Future<void> _loadMirroredDevices() async {
    final raw = await _read(key: _mirroredDevicesStorageKey);
    if (raw == null) {
      _mirroredDevices = const [];
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List;
      _mirroredDevices = List.unmodifiable(
        decoded.map((d) => MirroredDevice.fromMap(d as Map<String, dynamic>)),
      );
    } catch (_) {
      _mirroredDevices = const [];
    }
  }

  Future<void> addMirroredDevice(MirroredDevice device) => _tasks.run(() async {
    final updated = [
      ..._mirroredDevices.where((d) => d.id != device.id),
      device,
    ];
    _mirroredDevices = List.unmodifiable(updated);
    await _write(
      key: _mirroredDevicesStorageKey,
      value: jsonEncode(updated.map((d) => d.toMap()).toList()),
    );
    notifyListeners();
  });

  Future<void> removeMirroredDevice(String deviceId) => _tasks.run(() async {
    final updated = _mirroredDevices.where((d) => d.id != deviceId).toList();
    _mirroredDevices = List.unmodifiable(updated);
    await _write(
      key: _mirroredDevicesStorageKey,
      value: jsonEncode(updated.map((d) => d.toMap()).toList()),
    );
    notifyListeners();
  });

  Future<void> importMirroredAccount({
    required User user,
    required List<int> privateSeed,
  }) => _tasks.run(() async {
    final publicKey = IdentityProtocol.normalize(user.publicKey);
    if (user.id != publicKey) {
      throw const FormatException('Identidade inválida.');
    }
    if (privateSeed.length != 32) {
      throw const FormatException('Chave privada inválida.');
    }
    final identity = await _ed25519.newKeyPairFromSeed(privateSeed);
    final extractedKey = base64Encode((await identity.extractPublicKey()).bytes);
    if (extractedKey != publicKey) {
      throw StateError('A chave privada não corresponde à conta.');
    }
    await _write(
      key: _accountStorageKey,
      value: await _serializeAccount(user, identity),
    );
    _currentUser = user;
    _identity = identity;
    _owner = null;
    _setConversations(const []);
    await _loadMirroredDevices();
    notifyListeners();
  });

  Future<void> signIn(String nickname) => _tasks.run(() async {
    final normalized = nickname.trim();
    if (normalized.isEmpty || normalized.length > 32) {
      throw ArgumentError('Informe um apelido de 1 a 32 caracteres.');
    }
    final identity = await _ed25519.newKeyPair();
    final publicKey = base64Encode((await identity.extractPublicKey()).bytes);
    final user = _createLocalUser(
      nickname: normalized,
    ).copyWith(id: publicKey, publicKey: publicKey, clearNickname: false);
    await _write(
      key: _accountStorageKey,
      value: await _serializeAccount(user, identity),
    );
    _currentUser = user;
    _identity = identity;
    _owner = null;
    _setConversations(const []);
    notifyListeners();
  });

  Future<void> updateNickname(String? nickname) => _update((user) {
    final normalized = nickname?.trim() ?? '';
    if (normalized.isEmpty || normalized.length > 32) {
      throw ArgumentError('Use de 1 a 32 caracteres.');
    }
    return user.copyWith(nickname: normalized, clearNickname: false);
  });

  Future<void> setBlocked(String publicKey, bool blocked) => _update((user) {
    final key = IdentityProtocol.normalize(publicKey);
    if (key == user.publicKey) {
      throw ArgumentError('Não é possível bloquear sua própria identidade.');
    }
    final keys = user.blockedUserIds.toSet();
    if (blocked) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
    return user.copyWith(
      blockedUserIds: List.unmodifiable(keys),
      clearNickname: false,
    );
  });

  Future<void> _update(User Function(User) update) {
    return _tasks.run(() async {
      final updated = update(_currentUser);
      await _write(
        key: _accountStorageKey,
        value: await _serializeAccount(updated, identityKeyPair),
      );
      _currentUser = updated;
      notifyListeners();
    });
  }

  static User _createLocalUser({required String nickname}) {
    final random = Random.secure();
    final id = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final now = DateTime.now();
    return User(
      id: id,
      nickname: nickname,
      publicKey: '',
      createdAt: now,
      lastSeenAt: now,
      isActive: false,
      blockedUserIds: const [],
    );
  }

  final Map<String, String> _contactNames = {};
  bool hasContactName(String key) =>
      key == currentUser.id || _contactNames.containsKey(key);
  String contactName(String key) => key == currentUser.id
      ? currentUser.nickname
      : (_contactNames[key] ?? 'Aguardando apelido');
  String conversationName(Conversation c) {
    if (c.isSavedMessages) return 'Mensagens Salvas';
    return c.isGroup
        ? c.title
        : contactName(
            c.participantIds.firstWhere(
              (id) => id != currentUser.id,
              orElse: () => '',
            ),
          );
  }

  Future<void> updateContactName(String key, String name) =>
      _tasks.run(() async {
        final normalized = IdentityProtocol.normalize(key);
        final nickname = name.trim();
        if (nickname.isEmpty ||
            nickname.length > 32 ||
            normalized == _owner ||
            isBlocked(normalized)) {
          return;
        }
        if (_contactNames[normalized] == nickname) return;
        final previous = _contactNames[normalized];
        _contactNames[normalized] = nickname;
        try {
          await _persist(_conversations);
        } catch (_) {
          if (previous == null) {
            _contactNames.remove(normalized);
          } else {
            _contactNames[normalized] = previous;
          }
          rethrow;
        }
        notifyListeners();
      });

  List<Conversation> _conversations = const [];
  List<Conversation> _activeConversations = const [];
  String? _owner;

  void _setConversations(List<Conversation> items) {
    _conversations = items;
    _activeConversations = List.unmodifiable(
      items.where((c) => c.status == ConversationStatus.active),
    );
  }

  List<Conversation> get conversations => _activeConversations;

  String get _key =>
      'nexora.conversations.v2.${base64UrlEncode(utf8.encode(_owner!))}';

  Future<void> load(
    String ownerId, {
    int retentionMinutes = 0,
  }) => _tasks.run(() async {
    final owner = IdentityProtocol.normalize(ownerId);
    _owner = owner;
    _contactNames.clear();
    _setConversations(const []);
    final raw = await _read(key: _key);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['v'] != 2 || decoded['owner'] != owner) {
        throw const FormatException('Dados de conversas inválidos.');
      }
      final contacts = decoded['contacts'] as Map<String, dynamic>? ?? {};
      for (final entry in contacts.entries) {
        final key = IdentityProtocol.normalize(entry.key);
        final name = entry.value as String;
        if (name.trim().isNotEmpty && name.length <= 32) {
          _contactNames[key] = name;
        }
      }
      final loaded = (decoded['conversations'] as List)
          .map((v) => Conversation.fromMap(v as Map<String, dynamic>))
          .toList();
      final cutoff = DateTime.now().subtract(
        Duration(minutes: retentionMinutes),
      );
      for (final c in loaded) {
        final isValidParticipants = c.isSavedMessages
            ? (c.participantIds.length == 1 && c.participantIds.contains(owner))
            : (c.participantIds.toSet().length == c.participantIds.length &&
                c.participantIds.contains(owner) &&
                (c.isGroup
                    ? c.participantIds.length >= 3
                    : c.participantIds.length == 2));
        if (!isValidParticipants) {
          throw const FormatException('Participantes inválidos.');
        }
        for (final participant in c.participantIds) {
          IdentityProtocol.normalize(participant);
        }
      }
      final filtered = loaded.map((c) {
        final messages = c.messages
            .where(
              (m) =>
                  retentionMinutes == -1 ||
                  (retentionMinutes > 0 && m.receivedAt.isAfter(cutoff)),
            )
            .toList();
        return c.copyWith(messages: messages);
      }).toList();
      _setConversations(filtered);
      await _persist(_conversations);
    }
    notifyListeners();
  });

  Future<Conversation> createConversation({
    required String title,
    required List<String> participantIds,
    bool isGroup = false,
    String? groupId,
  }) => _tasks.run(() async {
    if (_owner == null) {
      throw StateError('Carregue a identidade antes das conversas.');
    }
    final participants = participantIds
        .map(IdentityProtocol.normalize)
        .toSet()
        .toList();
    if ((isGroup ? participants.length < 3 : participants.length != 2) ||
        !participants.contains(_owner)) {
      throw ArgumentError(
        'Informe a chave de outra pessoa para uma conversa P2P.',
      );
    }
    if (!isGroup && groupId != null) {
      throw ArgumentError('Identificador de grupo inválido.');
    }
    for (final existing in _conversations) {
      if (isGroup && existing.id == groupId) {
        if (!existing.isGroup ||
            existing.participantIds.length != participants.length ||
            !existing.participantIds.toSet().containsAll(participants)) {
          throw const FormatException(
            'Os membros do grupo não correspondem ao convite.',
          );
        }
        return existing;
      }
      if (!isGroup &&
          !existing.isGroup &&
          existing.participantIds.toSet().containsAll(participants)) {
        return existing;
      }
    }
    if (isGroup && (title.trim().isEmpty || title.trim().length > 48)) {
      throw ArgumentError('Informe um nome de grupo de até 48 caracteres.');
    }
    final now = DateTime.now();
    final conversation = Conversation(
      id: groupId ?? const Uuid().v4(),
      isGroup: isGroup,
      title: isGroup ? title.trim() : '',
      participantIds: participants,
      messages: const [],
      createdAt: now,
      updatedAt: now,
      unreadCount: 0,
    );
    final updated = [..._conversations, conversation];
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
    return conversation;
  });

  Future<void> updateHistory(String conversationId, List<Message> messages) {
    final snapshot = List<Message>.unmodifiable(messages);
    return _tasks.run(() async {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index == -1) {
        throw StateError('Conversa não encontrada no armazenamento local.');
      }
      final existing = _conversations[index];
      for (final message in snapshot) {
        if (!existing.participantIds.contains(message.senderId)) {
          throw const FormatException('Remetente inválido.');
        }
      }
      final updated = [..._conversations];
      updated[index] = existing.copyWith(
        messages: snapshot,
        updatedAt: DateTime.now(),
      );
      await _persist(updated);
      _setConversations(updated);
      notifyListeners();
    });
  }

  Future<void> renameConversation(String id, String title) =>
      _tasks.run(() async {
        final normalized = title.trim();
        if (normalized.isEmpty || normalized.length > 48) {
          throw ArgumentError('Use de 1 a 48 caracteres.');
        }
        final index = _conversations.indexWhere((c) => c.id == id);
        if (index == -1) throw StateError('Conversa não encontrada.');
        final updated = [..._conversations];
        updated[index] = updated[index].copyWith(title: normalized);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<Conversation> getOrCreateSavedMessages() => _tasks.run(() async {
    if (_owner == null) {
      throw StateError('Carregue a identidade antes das conversas.');
    }
    for (final c in _conversations) {
      if (c.isSavedMessages) return c;
    }
    final now = DateTime.now();
    final conversation = Conversation(
      id: 'saved_messages_${_owner!}',
      title: 'Mensagens Salvas',
      participantIds: [_owner!],
      messages: const [],
      createdAt: now,
      updatedAt: now,
      unreadCount: 0,
      isSavedMessages: true,
      isPinned: true,
    );
    final updated = [conversation, ..._conversations];
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
    return conversation;
  });

  Future<void> togglePinConversation(String id) => _tasks.run(() async {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final updated = [..._conversations];
    updated[index] = updated[index].copyWith(
      isPinned: !updated[index].isPinned,
    );
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
  });

  Future<void> toggleMuteConversation(String id) => _tasks.run(() async {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index == -1) return;
    final updated = [..._conversations];
    updated[index] = updated[index].copyWith(
      isMuted: !updated[index].isMuted,
    );
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
  });

  Future<Conversation> createCommunity({
    required String title,
    String? description,
    List<String>? channels,
    required List<String> participantKeys,
  }) => _tasks.run(() async {
    final ownerKey = _owner;
    if (ownerKey == null) throw StateError('Identidade não inicializada.');
    final normalized = title.trim();
    if (normalized.isEmpty || normalized.length > 48) {
      throw ArgumentError('O nome da comunidade deve ter entre 1 e 48 caracteres.');
    }
    final participants = <String>{ownerKey};
    for (final key in participantKeys) {
      final norm = IdentityProtocol.normalize(key);
      if (isBlocked(norm)) throw StateError('Contato bloqueado.');
      participants.add(norm);
    }
    final now = DateTime.now();
    final defaultChannels = (channels == null || channels.isEmpty)
        ? ['geral', 'anúncios', 'mídia']
        : channels;
    final community = Conversation(
      id: 'comm_${now.millisecondsSinceEpoch}_${participants.length}',
      title: normalized,
      isGroup: true,
      isCommunity: true,
      channels: defaultChannels,
      description: description?.trim(),
      adminIds: [ownerKey],
      creatorId: ownerKey,
      participantIds: participants.toList(growable: false),
      messages: const [],
      createdAt: now,
      updatedAt: now,
      unreadCount: 0,
    );
    final updated = [community, ..._conversations];
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
    return community;
  });

  Future<void> addChannelToConversation(String conversationId, String channelName) =>
      _tasks.run(() async {
        final norm = channelName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
        if (norm.isEmpty || norm.length > 32) return;
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final currentChannels = conv.channels.isNotEmpty ? [...conv.channels] : ['geral'];
        if (!currentChannels.contains(norm)) {
          currentChannels.add(norm);
        }
        final updated = [..._conversations];
        updated[index] = conv.copyWith(channels: currentChannels);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> removeChannelFromConversation(String conversationId, String channelName) =>
      _tasks.run(() async {
        final norm = channelName.trim().toLowerCase();
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final currentChannels = conv.channels.isNotEmpty ? [...conv.channels] : ['geral'];
        if (currentChannels.length <= 1) {
          throw StateError('A comunidade precisa ter pelo menos um canal.');
        }
        currentChannels.removeWhere((c) => c.toLowerCase() == norm);
        final updated = [..._conversations];
        updated[index] = conv.copyWith(channels: currentChannels);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> renameChannelInConversation(String conversationId, String oldChannel, String newChannel) =>
      _tasks.run(() async {
        final oldNorm = oldChannel.trim().toLowerCase();
        final newNorm = newChannel.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
        if (newNorm.isEmpty || newNorm.length > 32) return;
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final currentChannels = conv.channels.isNotEmpty ? [...conv.channels] : ['geral'];
        final chIndex = currentChannels.indexWhere((c) => c.toLowerCase() == oldNorm);
        if (chIndex == -1) return;
        currentChannels[chIndex] = newNorm;

        final updatedMessages = conv.messages.map((m) {
          if (m.channel?.toLowerCase() == oldNorm) {
            return m.copyWith(channel: newNorm);
          }
          return m;
        }).toList();

        final updated = [..._conversations];
        updated[index] = conv.copyWith(
          channels: currentChannels,
          messages: updatedMessages,
        );
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> addMemberToCommunity(String conversationId, String participantKey) =>
      _tasks.run(() async {
        final norm = IdentityProtocol.normalize(participantKey);
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final current = [...conv.participantIds];
        if (!current.contains(norm)) {
          current.add(norm);
        }
        final updated = [..._conversations];
        updated[index] = conv.copyWith(participantIds: current);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> removeMemberFromCommunity(String conversationId, String participantKey) =>
      _tasks.run(() async {
        final norm = IdentityProtocol.normalize(participantKey);
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final current = [...conv.participantIds];
        current.remove(norm);
        final currentAdmins = [...conv.adminIds];
        currentAdmins.remove(norm);
        final updated = [..._conversations];
        updated[index] = conv.copyWith(
          participantIds: current,
          adminIds: currentAdmins,
        );
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> toggleCommunityAdmin(String conversationId, String participantKey) =>
      _tasks.run(() async {
        final norm = IdentityProtocol.normalize(participantKey);
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final currentAdmins = [...conv.adminIds];
        if (currentAdmins.contains(norm)) {
          currentAdmins.remove(norm);
        } else {
          currentAdmins.add(norm);
        }
        final updated = [..._conversations];
        updated[index] = conv.copyWith(adminIds: currentAdmins);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> clearCommunityMessages(String conversationId, {String? channel}) =>
      _tasks.run(() async {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final updatedMessages = channel == null
            ? <Message>[]
            : conv.messages.where((m) => m.channel?.toLowerCase() != channel.toLowerCase()).toList();
        final updated = [..._conversations];
        updated[index] = conv.copyWith(
          messages: updatedMessages,
          unreadCount: 0,
        );
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> updateConversationDescription(String conversationId, String description) =>
      _tasks.run(() async {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final updated = [..._conversations];
        updated[index] = conv.copyWith(description: description.trim());
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> setPrivateContactNotes(String conversationId, String notes) =>
      _tasks.run(() async {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final updated = [..._conversations];
        updated[index] = conv.copyWith(privateContactNotes: notes.trim());
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> setSafetyVerified(String conversationId, bool verified) =>
      _tasks.run(() async {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index == -1) return;
        final conv = _conversations[index];
        final updated = [..._conversations];
        updated[index] = conv.copyWith(isSafetyVerified: verified);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> votePoll(
    String conversationId,
    int messageId,
    int optionIndex,
    String voterId,
  ) => _tasks.run(() async {
    final cIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (cIndex == -1) return;
    final conv = _conversations[cIndex];
    final mIndex = conv.messages.indexWhere((m) => m.messageId == messageId);
    if (mIndex == -1) return;

    final msg = conv.messages[mIndex];
    final currentVotes = Map<String, List<String>>.from(
      msg.pollVotes.map((k, v) => MapEntry(k, List<String>.from(v))),
    );

    for (final k in currentVotes.keys.toList()) {
      currentVotes[k]?.remove(voterId);
    }
    final key = optionIndex.toString();
    final list = currentVotes[key] ?? [];
    list.add(voterId);
    currentVotes[key] = list;

    final updatedMsgs = [...conv.messages];
    updatedMsgs[mIndex] = msg.copyWith(pollVotes: currentVotes);

    final updated = [..._conversations];
    updated[cIndex] = conv.copyWith(messages: updatedMsgs);
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
  });

  Future<void> markViewOnceAsViewed(String conversationId, int messageId) =>
      _tasks.run(() async {
        final cIndex = _conversations.indexWhere((c) => c.id == conversationId);
        if (cIndex == -1) return;
        final conv = _conversations[cIndex];
        final mIndex = conv.messages.indexWhere((m) => m.messageId == messageId);
        if (mIndex == -1) return;

        final msg = conv.messages[mIndex];
        if (msg.viewedAt != null) return;
        final updatedMsgs = [...conv.messages];
        updatedMsgs[mIndex] = msg.copyWith(viewedAt: DateTime.now());

        final updated = [..._conversations];
        updated[cIndex] = conv.copyWith(messages: updatedMsgs);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> setEphemeralRetention(String id, int? seconds) =>
      _tasks.run(() async {
        final index = _conversations.indexWhere((c) => c.id == id);
        if (index == -1) return;
        final updated = [..._conversations];
        updated[index] = updated[index].copyWith(
          ephemeralRetentionSeconds: seconds,
        );
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> togglePinMessage(String conversationId, int messageId) =>
      _tasks.run(() async {
        final cIndex = _conversations.indexWhere((c) => c.id == conversationId);
        if (cIndex == -1) return;
        final conv = _conversations[cIndex];
        final mIndex = conv.messages.indexWhere((m) => m.messageId == messageId);
        if (mIndex == -1) return;

        final msg = conv.messages[mIndex];
        final newPinned = !msg.isPinned;
        final updatedMsgs = [...conv.messages];
        updatedMsgs[mIndex] = msg.copyWith(isPinned: newPinned);

        final pinnedIds = conv.pinnedMessageIds.toSet();
        final strId = messageId.toString();
        if (newPinned) {
          pinnedIds.add(strId);
        } else {
          pinnedIds.remove(strId);
        }

        final updated = [..._conversations];
        updated[cIndex] = conv.copyWith(
          messages: updatedMsgs,
          pinnedMessageIds: pinnedIds.toList(),
        );
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> toggleStarMessage(String conversationId, int messageId) =>
      _tasks.run(() async {
        final cIndex = _conversations.indexWhere((c) => c.id == conversationId);
        if (cIndex == -1) return;
        final conv = _conversations[cIndex];
        final mIndex = conv.messages.indexWhere((m) => m.messageId == messageId);
        if (mIndex == -1) return;

        final msg = conv.messages[mIndex];
        final updatedMsgs = [...conv.messages];
        updatedMsgs[mIndex] = msg.copyWith(isStarred: !msg.isStarred);

        final updated = [..._conversations];
        updated[cIndex] = conv.copyWith(messages: updatedMsgs);
        await _persist(updated);
        _setConversations(updated);
        notifyListeners();
      });

  Future<void> toggleMessageReaction(
    String conversationId,
    int messageId,
    String emoji,
    String userId,
  ) => _tasks.run(() async {
    final cIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (cIndex == -1) return;
    final conv = _conversations[cIndex];
    final mIndex = conv.messages.indexWhere((m) => m.messageId == messageId);
    if (mIndex == -1) return;

    final msg = conv.messages[mIndex];
    final currentReactions = Map<String, List<String>>.from(
      msg.reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
    );

    final users = currentReactions[emoji] ?? [];
    if (users.contains(userId)) {
      users.remove(userId);
      if (users.isEmpty) {
        currentReactions.remove(emoji);
      } else {
        currentReactions[emoji] = users;
      }
    } else {
      users.add(userId);
      currentReactions[emoji] = users;
    }

    final updatedMsgs = [...conv.messages];
    updatedMsgs[mIndex] = msg.copyWith(reactions: currentReactions);

    final updated = [..._conversations];
    updated[cIndex] = conv.copyWith(messages: updatedMsgs);
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
  });

  String exportConversationToText(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return '';
    final conv = _conversations[index];
    final title = conversationName(conv);

    final buffer = StringBuffer();
    buffer.writeln('=== NEXORA E2EE CHAT BACKUP ===');
    buffer.writeln('Conversa: $title');
    buffer.writeln('Exportado em: ${DateTime.now().toLocal()}');
    buffer.writeln('Total de mensagens: ${conv.messages.length}');
    buffer.writeln('----------------------------------------\n');

    for (final m in conv.messages) {
      final sender = m.senderId == _owner ? 'Você' : contactName(m.senderId);
      final time = m.sentAt.toLocal();
      final timeStr =
          '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      buffer.writeln('[$timeStr] $sender:');
      if (m.replySnippet != null) {
        buffer.writeln('  > Respondendo a ${m.replySender ?? 'mensagem'}: "${m.replySnippet}"');
      }
      buffer.writeln('  ${m.textMsg}');
      if (m.reactions.isNotEmpty) {
        final reacs = m.reactions.entries
            .map((e) => '${e.key} (${e.value.length})')
            .join(' ');
        buffer.writeln('  Reações: $reacs');
      }
      buffer.writeln();
    }
    buffer.writeln('=== FIM DO BACKUP ===');
    return buffer.toString();
  }

  Future<void> deleteConversation(String id) => _tasks.run(() async {
    final updated = _conversations.where((c) => c.id != id).toList();
    await _persist(updated);
    _setConversations(updated);
    notifyListeners();
  });

  /// Apaga permanentemente todos os dados locais, identidade e histórico
  Future<void> wipeAllData() => _tasks.run(() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    _currentUser = _createLocalUser(nickname: '');
    _identity = null;
    _owner = null;
    _mirroredDevices = const [];
    _setConversations(const []);
    _contactNames.clear();
    notifyListeners();
  });

  Future<void> _persist(List<Conversation> conversations) async {
    if (_owner == null) throw StateError('Identidade não inicializada.');
    await _write(
      key: _key,
      value: jsonEncode({
        'v': 2,
        'owner': _owner,
        'contacts': Map<String, String>.from(_contactNames),
        'conversations': conversations.map((c) => c.toMap()).toList(),
      }),
    );
  }
}
