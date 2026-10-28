import 'package:nexora/src/services/identity_protocol.dart';

import 'dart:convert';
import 'dart:math';

import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/models/message.dart';
import 'package:uuid/uuid.dart';
import 'package:nexora/src/utils/serial_task_queue.dart';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexora/src/models/user.dart';

class LocalDataService extends ChangeNotifier {
  LocalDataService({
    User? initialUser,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage,
       _currentUser = initialUser ?? _createLocalUser(nickname: '');
  static final LocalDataService instance = LocalDataService();
  static const _accountStorageKey = 'nexora.account.v2';
  User _currentUser;
  SimpleKeyPair? _identity;
  final _tasks = SerialTaskQueue();
  bool isBlocked(String publicKey) =>
      _currentUser.blockedUserIds.contains(publicKey);
  final FlutterSecureStorage _storage;
  // Browsers cannot provide OS-backed secret storage. Keep secrets in memory.
  final Map<String, String> _webSession = {};
  Future<String?> _read({required String key}) async =>
      kIsWeb ? _webSession[key] : await _storage.read(key: key);
  Future<void> _write({required String key, required String value}) async {
    if (kIsWeb) {
      _webSession[key] = value;
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  User get currentUser => _currentUser;
  SimpleKeyPair get identityKeyPair =>
      _identity ?? (throw StateError('Identidade não inicializada.'));

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
    if (data['v'] != 2)
      throw const FormatException('Formato de conta não suportado.');
    final user = User.fromMap(data['user'] as Map<String, dynamic>);
    final publicKey = IdentityProtocol.normalize(user.publicKey);
    if (user.id != publicKey)
      throw const FormatException('Identidade inválida.');
    final seed = base64Decode(data['privateSeed'] as String);
    if (seed.length != 32)
      throw const FormatException('Chave privada inválida.');
    final identity = await Ed25519().newKeyPairFromSeed(seed);
    if (base64Encode((await identity.extractPublicKey()).bytes) != publicKey) {
      throw StateError('A chave privada não corresponde à conta.');
    }
    _currentUser = user;
    _identity = identity;
    if (_owner != user.id) {
      _owner = null;
      _conversations = [];
    }
    notifyListeners();
    return true;
  });

  Future<void> signIn(String nickname) => _tasks.run(() async {
    final normalized = nickname.trim();
    if (normalized.isEmpty || normalized.length > 32)
      throw ArgumentError('Informe um apelido de 1 a 32 caracteres.');
    final identity = await Ed25519().newKeyPair();
    final publicKey = base64Encode((await identity.extractPublicKey()).bytes);
    final user = _createLocalUser(nickname: normalized)
        .copyWith(id: publicKey, publicKey: publicKey, clearNickname: false);
    await _write(
      key: _accountStorageKey,
      value: await _serializeAccount(user, identity),
    );
    _currentUser = user;
    _identity = identity;
    _owner = null;
    _conversations = [];
    notifyListeners();
  });

  Future<void> updateNickname(String? nickname) => _update((user) {
    final normalized = nickname?.trim() ?? '';
    if (normalized.isEmpty || normalized.length > 32)
      throw ArgumentError('Use de 1 a 32 caracteres.');
    return user.copyWith(nickname: normalized, clearNickname: false);
  });

  Future<void> setBlocked(String publicKey, bool blocked) => _update((user) {
    final key = IdentityProtocol.normalize(publicKey);
    if (key == user.publicKey)
      throw ArgumentError('Não é possível bloquear sua própria identidade.');
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
      blockedUserIds: [],
    );
  }

  final Map<String, String> _contactNames = {};
  bool hasContactName(String key) =>
      key == currentUser.id || _contactNames.containsKey(key);
  String contactName(String key) => key == currentUser.id
      ? currentUser.nickname
      : (_contactNames[key] ?? 'Aguardando apelido');
  String conversationName(Conversation c) => c.isGroup
      ? c.title
      : contactName(c.participantIds.firstWhere((id) => id != currentUser.id));

  Future<void> updateContactName(String key, String name) =>
      _tasks.run(() async {
        final normalized = IdentityProtocol.normalize(key);
        final nickname = name.trim();
        if (nickname.isEmpty ||
            nickname.length > 32 ||
            normalized == _owner ||
            isBlocked(normalized))
          return;
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

  List<Conversation> _conversations = [];
  String? _owner;

  List<Conversation> get conversations => List.unmodifiable(
    _conversations.where((c) => c.status == ConversationStatus.active),
  );
  String get _key =>
      'nexora.conversations.v2.${base64UrlEncode(utf8.encode(_owner!))}';

  Future<void> load(
    String ownerId, {
    int retentionMinutes = 0,
  }) => _tasks.run(() async {
    final owner = IdentityProtocol.normalize(ownerId);
    _owner = owner;
    _contactNames.clear();
    _conversations = [];
    final raw = await _read(key: _key);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['v'] != 2 || decoded['owner'] != owner)
        throw const FormatException('Dados de conversas inválidos.');
      final contacts = decoded['contacts'] as Map<String, dynamic>? ?? {};
      for (final entry in contacts.entries) {
        final key = IdentityProtocol.normalize(entry.key);
        final name = entry.value as String;
        if (name.trim().isNotEmpty && name.length <= 32)
          _contactNames[key] = name;
      }
      final loaded = (decoded['conversations'] as List)
          .map((v) => Conversation.fromMap(v as Map<String, dynamic>))
          .toList();
      final cutoff = DateTime.now().subtract(
        Duration(minutes: retentionMinutes),
      );
      for (final c in loaded) {
        if (c.participantIds.toSet().length != c.participantIds.length ||
            !c.participantIds.contains(owner) ||
            (c.isGroup
                ? c.participantIds.length < 3
                : c.participantIds.length != 2))
          throw const FormatException('Participantes inválidos.');
        for (final participant in c.participantIds) {
          IdentityProtocol.normalize(participant);
        }
      }
      _conversations = loaded.map((c) {
        final messages = c.messages
            .where(
              (m) =>
                  retentionMinutes == -1 ||
                  (retentionMinutes > 0 && m.receivedAt.isAfter(cutoff)),
            )
            .toList();
        return c.copyWith(messages: messages);
      }).toList();
      // Expired or session-only history is removed from protected storage too.
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
    if (_owner == null)
      throw StateError('Carregue a identidade antes das conversas.');
    final participants = participantIds
        .map(IdentityProtocol.normalize)
        .toSet()
        .toList();
    if ((isGroup ? participants.length < 3 : participants.length != 2) ||
        !participants.contains(_owner))
      throw ArgumentError(
        'Informe a chave de outra pessoa para uma conversa P2P.',
      );
    if (!isGroup && groupId != null)
      throw ArgumentError('Identificador de grupo invalido.');
    for (final existing in _conversations) {
      if (isGroup && existing.id == groupId) {
        if (!existing.isGroup ||
            existing.participantIds.length != participants.length ||
            !existing.participantIds.toSet().containsAll(participants))
          throw const FormatException(
            'Os membros do grupo nao correspondem ao convite.',
          );
        return existing;
      }
      if (!isGroup &&
          !existing.isGroup &&
          existing.participantIds.toSet().containsAll(participants))
        return existing;
    }
    if (isGroup && (title.trim().isEmpty || title.trim().length > 48))
      throw ArgumentError('Informe um nome de grupo de ate 48 caracteres.');
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
    _conversations = updated;
    notifyListeners();
    return conversation;
  });

  Future<void> updateHistory(String conversationId, List<Message> messages) {
    // Freeze the caller's snapshot before enqueueing asynchronous I/O.
    final snapshot = List<Message>.unmodifiable(messages);
    return _tasks.run(() async {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index == -1)
        throw StateError('Conversa não encontrada no armazenamento local.');
      final existing = _conversations[index];
      for (final message in snapshot) {
        if (!existing.participantIds.contains(message.senderId))
          throw const FormatException('Remetente inválido.');
      }
      final updated = [..._conversations];
      updated[index] = existing.copyWith(
        messages: snapshot,
        updatedAt: DateTime.now(),
      );
      await _persist(updated);
      _conversations = updated;
      notifyListeners();
    });
  }

  Future<void> renameConversation(String id, String title) =>
      _tasks.run(() async {
        final normalized = title.trim();
        if (normalized.isEmpty || normalized.length > 48)
          throw ArgumentError('Use de 1 a 48 caracteres.');
        final index = _conversations.indexWhere((c) => c.id == id);
        if (index == -1) throw StateError('Conversa não encontrada.');
        final updated = [..._conversations];
        updated[index] = updated[index].copyWith(title: normalized);
        await _persist(updated);
        _conversations = updated;
        notifyListeners();
      });

  Future<void> deleteConversation(String id) => _tasks.run(() async {
    final updated = _conversations.where((c) => c.id != id).toList();
    await _persist(updated);
    _conversations = updated;
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
