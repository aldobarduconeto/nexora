import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:nexora/src/models/mirrored_device.dart';
import 'package:nexora/src/models/user.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:uuid/uuid.dart';

class NexoraMirrorRequest {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String ephemeralPublicKey;
  final DateTime timestamp;

  const NexoraMirrorRequest({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.ephemeralPublicKey,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'protocol': 'nexora-mirror-v1',
    'type': 'mirror_request',
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'ephemeralPublicKey': ephemeralPublicKey,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  String serialize() => jsonEncode(toMap());

  factory NexoraMirrorRequest.fromMap(Map<String, dynamic> map) {
    if (map['protocol'] != 'nexora-mirror-v1' ||
        map['type'] != 'mirror_request') {
      throw const FormatException('Formato de QR Code incompatível.');
    }
    return NexoraMirrorRequest(
      deviceId: map['deviceId'] as String? ?? const Uuid().v4(),
      deviceName: (map['deviceName'] as String?)?.trim().isNotEmpty == true
          ? (map['deviceName'] as String).trim()
          : 'Dispositivo desconhecido',
      platform: (map['platform'] as String?)?.toLowerCase() ?? 'unknown',
      ephemeralPublicKey: map['ephemeralPublicKey'] as String? ?? '',
      timestamp: map['timestamp'] is String
          ? DateTime.parse(map['timestamp'] as String).toLocal()
          : DateTime.now(),
    );
  }

  factory NexoraMirrorRequest.deserialize(String raw) {
    final decoded = jsonDecode(raw.trim()) as Map<String, dynamic>;
    return NexoraMirrorRequest.fromMap(decoded);
  }
}

class NexoraMirrorSession {
  final NexoraMirrorRequest request;
  final SimpleKeyPair receiverEphemeralKeyPair;

  const NexoraMirrorSession({
    required this.request,
    required this.receiverEphemeralKeyPair,
  });
}

class DeviceMirrorService {
  DeviceMirrorService._();
  static final DeviceMirrorService instance = DeviceMirrorService._();

  static final X25519 _x25519 = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();

  String detectPlatform() {
    try {
      if (kIsWeb) return 'web';
      return Platform.operatingSystem.toLowerCase();
    } catch (_) {
      return 'unknown';
    }
  }

  String detectDeviceName() {
    try {
      if (kIsWeb) return 'Navegador Web';
      final host = Platform.localHostname.trim();
      final hasHost = host.isNotEmpty && host != 'localhost';
      switch (Platform.operatingSystem.toLowerCase()) {
        case 'windows':
          return hasHost ? 'PC Windows ($host)' : 'Computador Windows';
        case 'macos':
          return hasHost ? 'Mac ($host)' : 'Computador Mac';
        case 'linux':
          return hasHost ? 'Linux ($host)' : 'Computador Linux';
        case 'android':
          return hasHost ? 'Android ($host)' : 'Celular Android';
        case 'ios':
          return hasHost ? 'iPhone/iPad ($host)' : 'Dispositivo iOS';
        default:
          return hasHost ? 'Dispositivo ($host)' : 'Novo Dispositivo';
      }
    } catch (_) {
      return 'Novo Dispositivo';
    }
  }

  /// Gera a solicitação de espelhamento que será exibida como QR Code no centro da tela
  /// do dispositivo receptor.
  Future<NexoraMirrorSession> createMirrorRequest({String? customDeviceName}) async {
    final name = (customDeviceName?.trim().isNotEmpty == true)
        ? customDeviceName!.trim()
        : detectDeviceName();

    final ephemeralKeyPair = await _x25519.newKeyPair();
    final publicKey = await ephemeralKeyPair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);

    final request = NexoraMirrorRequest(
      deviceId: const Uuid().v4(),
      deviceName: name,
      platform: detectPlatform(),
      ephemeralPublicKey: publicKeyBase64,
      timestamp: DateTime.now(),
    );

    return NexoraMirrorSession(
      request: request,
      receiverEphemeralKeyPair: ephemeralKeyPair,
    );
  }

  /// Faz o parse do QR Code lido pelo dispositivo Host para identificar o dispositivo receptor.
  NexoraMirrorRequest parseMirrorRequest(String qrContent) {
    try {
      return NexoraMirrorRequest.deserialize(qrContent);
    } catch (_) {
      throw const FormatException(
        'O QR Code lido não é uma solicitação válida de espelhamento do Nexora.',
      );
    }
  }

  /// Executado no dispositivo Host: autoriza e criptografa a conta com a chave efêmera do receptor.
  Future<String> authorizeMirrorRequest({
    required NexoraMirrorRequest request,
    required User currentUser,
    required List<int> privateSeed,
  }) async {
    if (request.ephemeralPublicKey.isEmpty) {
      throw const FormatException('Chave pública do dispositivo receptor ausente.');
    }

    final receiverPublicKeyBytes = base64Decode(request.ephemeralPublicKey);
    final receiverPublicKey = SimplePublicKey(
      receiverPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    // Host gera sua chave efêmera
    final hostEphemeralKeyPair = await _x25519.newKeyPair();
    final hostPublicKey = await hostEphemeralKeyPair.extractPublicKey();

    // Acordo X25519 e derivação HKDF
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: hostEphemeralKeyPair,
      remotePublicKey: receiverPublicKey,
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derivedSecret = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(request.deviceId),
      info: utf8.encode('nexora-device-mirror-v1'),
    );

    // Carga de espelhamento a ser cifrada
    final payloadToEncrypt = jsonEncode({
      'user': currentUser.toMap(),
      'privateSeed': base64Encode(privateSeed),
      'hostDeviceName': detectDeviceName(),
      'authorizedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final secretBox = await _aesGcm.encrypt(
      utf8.encode(payloadToEncrypt),
      secretKey: derivedSecret,
    );

    // Salva o dispositivo receptor na lista de dispositivos espelhados do host
    await LocalDataService.instance.addMirroredDevice(
      MirroredDevice(
        id: request.deviceId,
        name: request.deviceName,
        platform: request.platform,
        pairedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ),
    );

    // Empacota resposta autorizada
    final authorizationPackage = {
      'protocol': 'nexora-mirror-v1',
      'type': 'mirror_authorization',
      'deviceId': request.deviceId,
      'hostEphemeralPublicKey': base64Encode(hostPublicKey.bytes),
      'cipherText': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    return jsonEncode(authorizationPackage);
  }

  /// Executado no dispositivo receptor: descriptografa os dados e importa a conta espelhada.
  Future<void> completeMirrorReceive({
    required String authorizationPackage,
    required SimpleKeyPair receiverEphemeralKeyPair,
  }) async {
    final data = jsonDecode(authorizationPackage.trim()) as Map<String, dynamic>;
    if (data['protocol'] != 'nexora-mirror-v1' ||
        data['type'] != 'mirror_authorization') {
      throw const FormatException('Pacote de autorização inválido.');
    }

    final hostPublicKeyBytes = base64Decode(
      data['hostEphemeralPublicKey'] as String,
    );
    final hostPublicKey = SimplePublicKey(
      hostPublicKeyBytes,
      type: KeyPairType.x25519,
    );
    final deviceId = data['deviceId'] as String;

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: receiverEphemeralKeyPair,
      remotePublicKey: hostPublicKey,
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derivedSecret = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(deviceId),
      info: utf8.encode('nexora-device-mirror-v1'),
    );

    final cipherText = base64Decode(data['cipherText'] as String);
    final nonce = base64Decode(data['nonce'] as String);
    final macBytes = base64Decode(data['mac'] as String);

    final decryptedBytes = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: derivedSecret,
    );

    final decryptedData =
        jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
    final userMap = decryptedData['user'] as Map<String, dynamic>;
    final privateSeed = base64Decode(decryptedData['privateSeed'] as String);

    final user = User.fromMap(userMap);
    await LocalDataService.instance.importMirroredAccount(
      user: user,
      privateSeed: privateSeed,
    );
  }
}
