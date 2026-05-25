import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/data/models/user_model.dart';

class FirebaseChatSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<MessageModel>> getMessages(int limit) {
    return _firestore
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(MessageModel.fromFirestore).toList());
  }

  Future<void> sendMessage(MessageModel message) async {
    await _firestore.collection('messages').add(message.toMap());
  }

  Future<String> uploadImage(File image) async {
    final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final Reference ref = _storage.ref().child('chat_images').child(fileName);
    final UploadTask uploadTask = ref.putFile(image);
    final TaskSnapshot snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<List<MessageModel>> getOlderMessages(DateTime before, int limit) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('messages')
        .where('timestamp', isLessThan: Timestamp.fromDate(before))
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(MessageModel.fromFirestore).toList();
  }

  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection('users')
        .where('isDeleted', isEqualTo: false)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirebase(doc.data(), doc.id))
            .toList());
  }

  Future<List<UserModel>> getUsersOnce() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('users')
        .where('isDeleted', isEqualTo: false)
        .orderBy('lastMessageTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromFirebase(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
