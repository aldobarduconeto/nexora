import 'package:flutter/widgets.dart';

enum AppText {
  identityFailed(
    'Não foi possível iniciar. Tente novamente.',
    'Could not start. Please try again.',
    'No se pudo iniciar. Inténtalo de nuevo.',
    'Impossible de démarrer. Veuillez réessayer.',
  ),
  encryptedCommunication(
    'Comunicação Direta e Privada',
    'Direct and private messaging',
    'Comunicación directa y privada',
    'Communication directe et privée',
  ),
  signInHeading(
    'Privacidade total.\nConversas diretas e seguras.',
    'Total privacy.\nDirect and secure conversations.',
    'Privacidad total.\nConversaciones directas y seguras.',
    'Confidentialité totale.\nConversations directes et sécurisées.',
  ),
  signInDescription(
    'Conecte-se livremente sem informar e-mail ou número de telefone. Suas mensagens e chamadas ficam salvas apenas no seu aparelho.',
    'Connect freely without email or phone numbers. Your messages and calls stay exclusively on your device.',
    'Conéctate libremente sin dar tu correo o teléfono. Tus mensajes y llamadas se guardan solo en tu dispositivo.',
    'Connectez-vous librement sans e-mail ni numéro de téléphone. Vos messages et appels restent uniquement sur votre appareil.',
  ),
  encryption(
    'Totalmente Protegido',
    'Fully protected',
    'Totalmente protegido',
    'Entièrement protégé',
  ),
  encryptionDetails(
    'Somente você e quem recebe podem ver suas mensagens e arquivos.',
    'Only you and your recipients can see your messages and files.',
    'Solo tú y tus destinatarios pueden ver tus mensajes y archivos.',
    'Seuls vous et vos destinataires pouvez voir vos messages et fichiers.',
  ),
  media(
    'Áudio e Vídeo em Alta Resolução',
    'High definition voice and video',
    'Voz y vídeo en alta definición',
    'Voix et vidéo haute définition',
  ),
  mediaDetails(
    'Chamadas fluidas e compartilhamento de tela direto entre aparelhos.',
    'Smooth calls and screen sharing directly between devices.',
    'Llamadas fluidas y pantalla compartida directamente entre dispositivos.',
    'Appels fluides et partage d’écran directement entre appareils.',
  ),
  localKey(
    'Seus Dados São Só Seus',
    'Your data stays yours',
    'Tus datos son solo tuyos',
    'Vos données vous appartiennent',
  ),
  localKeyDetails(
    'Sem cadastro de dados pessoais e sem histórico guardado na nuvem.',
    'No personal data collected and no history stored in the cloud.',
    'Sin datos personales ni historial guardado en la nube.',
    'Aucune donnée personnelle collectée ni historique dans le cloud.',
  ),
  nickname(
    'Seu nome ou apelido',
    'Your name or nickname',
    'Tu nombre o alias',
    'Votre nom ou pseudonyme',
  ),
  nicknameHint(
    'Como seus amigos verão você?',
    'How should your friends see you?',
    '¿Cómo te verán tus amigos?',
    'Comment vos amis vous verront-ils ?',
  ),
  nicknameRequired(
    'Informe um nome ou apelido.',
    'Please enter a name or nickname.',
    'Introduce un nombre o alias.',
    'Veuillez entrer un nom ou pseudonyme.',
  ),
  createIdentity(
    'Entrar no Nexora',
    'Enter Nexora',
    'Entrar en Nexora',
    'Accéder à Nexora',
  ),
  mirrorAccount(
    'Já tem conta em outro aparelho? Sincronizar',
    'Already have an account on another device? Sync',
    '¿Ya tienes cuenta en otro dispositivo? Sincronizar',
    'Déjà un compte sur un autre appareil ? Synchroniser',
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
