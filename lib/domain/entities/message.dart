class MessageEntity {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;

  MessageEntity({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    this.imageUrl,
    required this.timestamp,
  });
}
