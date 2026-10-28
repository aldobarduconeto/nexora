import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Public identities are Ed25519 keys, not routing addresses.
class IdentityProtocol {
  static String normalize(String value) {
    final raw = value.trim();
    if (raw.length != 44)
      throw const FormatException('Chave pública inválida.');
    final bytes = base64Decode(raw);
    if (bytes.length != 32 || bytes.every((b) => b == 0)) {
      throw const FormatException(
        'Informe uma chave pública Ed25519 Base64 de 32 bytes.',
      );
    }
    return base64Encode(bytes);
  }

  static Future<String> sign(
    Map<String, dynamic> payload,
    SimpleKeyPair key,
  ) async {
    final signature = await Ed25519().sign(
      utf8.encode(jsonEncode(payload)),
      keyPair: key,
    );
    return jsonEncode({
      'payload': payload,
      'signature': base64Encode(signature.bytes),
    });
  }

  static Future<Map<String, dynamic>> verify(
    String raw,
    String expectedKey,
  ) async {
    if (raw.length > 128 * 1024)
      throw const FormatException('Convite muito grande.');
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final payload = envelope['payload'] as Map<String, dynamic>;
    final identity = normalize(payload['identity'] as String);
    if (identity != normalize(expectedKey)) {
      throw const FormatException(
        'A assinatura não pertence à chave pública do contato.',
      );
    }
    final valid = await Ed25519().verify(
      utf8.encode(jsonEncode(payload)),
      signature: Signature(
        base64Decode(envelope['signature'] as String),
        publicKey: SimplePublicKey(
          base64Decode(identity),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valid)
      throw const FormatException('Convite adulterado ou assinatura inválida.');
    return payload;
  }
}
