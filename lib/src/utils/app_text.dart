import 'package:flutter/widgets.dart';

enum AppText {
  identityFailed(
    'Não foi possível criar a identidade. Tente novamente.',
    'Could not create your identity. Try again.',
    'No se pudo crear tu identidad. Inténtalo de nuevo.',
    'Impossible de créer votre identité. Réessayez.',
  ),
  encryptedCommunication(
    'Comunicação P2P Criptografada',
    'Encrypted P2P communication',
    'Comunicación P2P cifrada',
    'Communication P2P chiffrée',
  ),
  signInHeading(
    'Conversas, voz e vídeo.\nDireto entre dispositivos.',
    'Chat, voice and video.\nDirectly between devices.',
    'Chat, voz y vídeo.\nDirectamente entre dispositivos.',
    'Messages, voix et vidéo.\nDirectement entre appareils.',
  ),
  signInDescription(
    'Gere sua identidade criptográfica local em segundos. Sem telefone, e-mail ou servidores intermediários.',
    'Create a local cryptographic identity in seconds. No phone number, email or intermediary servers.',
    'Crea una identidad criptográfica local en segundos. Sin teléfono, correo ni servidores intermediarios.',
    'Créez une identité cryptographique locale en quelques secondes. Sans téléphone, e-mail ni serveur intermédiaire.',
  ),
  encryption(
    'Criptografia Ponta a Ponta',
    'End-to-end encryption',
    'Cifrado de extremo a extremo',
    'Chiffrement de bout en bout',
  ),
  encryptionDetails(
    'Identidade Ed25519, acordo X25519 e AES-256-GCM.',
    'Ed25519 identity, X25519 key agreement and AES-256-GCM.',
    'Identidad Ed25519, acuerdo de claves X25519 y AES-256-GCM.',
    'Identité Ed25519, accord de clés X25519 et AES-256-GCM.',
  ),
  media(
    'Voz, Vídeo e Tela até 4K@60fps',
    'Voice, video and screen sharing up to 4K at 60 fps',
    'Voz, vídeo y pantalla compartida hasta 4K a 60 fps',
    'Voix, vidéo et partage d’écran jusqu’à 4K à 60 i/s',
  ),
  mediaDetails(
    'Chamadas e streaming P2P em tempo real com DTLS-SRTP.',
    'Real-time P2P calls and streaming with DTLS-SRTP.',
    'Llamadas y transmisión P2P en tiempo real con DTLS-SRTP.',
    'Appels et diffusion P2P en temps réel avec DTLS-SRTP.',
  ),
  localKey(
    '100% Sob Seu Controle',
    'You control your private key',
    'Tú controlas tu clave privada',
    'Vous contrôlez votre clé privée',
  ),
  localKeyDetails(
    'Chave privada no cofre seguro local do dispositivo.',
    'Your private key is stored securely on this device.',
    'Tu clave privada se guarda de forma segura en este dispositivo.',
    'Votre clé privée est stockée en lieu sûr sur cet appareil.',
  ),
  nickname(
    'Seu apelido público',
    'Your public nickname',
    'Tu alias público',
    'Votre pseudonyme public',
  ),
  nicknameHint(
    'Como seus contatos verão você?',
    'How will your contacts see you?',
    '¿Cómo te verán tus contactos?',
    'Comment vos contacts vous verront-ils ?',
  ),
  nicknameRequired(
    'Informe um apelido.',
    'Enter a nickname.',
    'Introduce un alias.',
    'Saisissez un pseudonyme.',
  ),
  createIdentity(
    'Criar identidade local',
    'Create local identity',
    'Crear identidad local',
    'Créer une identité locale',
  ),
  mirrorAccount(
    'Espelhar conta de outro dispositivo',
    'Mirror an account from another device',
    'Replicar una cuenta de otro dispositivo',
    'Dupliquer un compte depuis un autre appareil',
  ),
  chats('Conversas', 'Chats', 'Conversaciones', 'Conversations'),
  communities('Comunidades', 'Communities', 'Comunidades', 'Communautés'),
  settings('Configurações', 'Settings', 'Configuración', 'Paramètres');

  const AppText(this.pt, this.en, this.es, this.fr);

  final String pt;
  final String en;
  final String es;
  final String fr;

  String of(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'en' => en,
        'es' => es,
        'fr' => fr,
        _ => pt,
      };
}
