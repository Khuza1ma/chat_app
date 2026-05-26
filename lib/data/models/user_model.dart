import 'package:chat_app/domain/entities/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel extends UserEntity {
  UserModel({
    required super.uid,
    required super.phoneNumber,
    super.displayName,
    super.photoUrl,
    super.username,
    super.lastMessage,
    super.lastMessageTime,
    super.createdAt,
    super.updatedAt,
    super.isActive,
    super.isDeleted,
    super.profileUrl,
  });

  factory UserModel.fromFirebase(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      phoneNumber: data['phoneNumber'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      username: data['username'],
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      isDeleted: data['isDeleted'] ?? false,
      profileUrl: data['profileUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'username': username,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'profileUrl': profileUrl,
    };
  }
}
