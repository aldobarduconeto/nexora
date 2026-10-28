class Message {
  final int messageId;
  final DateTime sentAt;
  final String textMsg;
  final String senderId;
  final String sessionId;
  final DateTime receivedAt;

  Message({
    required this.messageId,
    required this.sentAt,
    required this.textMsg,
    required this.senderId,
    required this.sessionId,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? sentAt;

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'textMsg': textMsg,
    'senderId': senderId,
    'sessionId': sessionId,
    'receivedAt': receivedAt.toUtc().toIso8601String(),
  };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    messageId: map['messageId'] as int,
    sentAt: DateTime.parse(map['sentAt'] as String),
    textMsg: map['textMsg'] as String,
    senderId: map['senderId'] as String,
    sessionId: map['sessionId'] as String,
    receivedAt: DateTime.parse(map['receivedAt'] as String),
  );
}
