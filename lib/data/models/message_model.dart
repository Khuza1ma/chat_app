import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/domain/entities/message.dart';

class MessageModel extends MessageEntity {
  MessageModel({
    required super.id,
    required super.senderId,
    required super.senderName,
    super.senderPhotoUrl,
    required super.text,
    super.imageUrl,
    required super.timestamp,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'],
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
