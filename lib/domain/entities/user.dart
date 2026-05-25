class UserEntity {
  final String uid;
  final String phoneNumber;
  final String? displayName;
  final String? photoUrl;
  final String? username;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final bool isDeleted;
  final String? profileUrl;

  UserEntity({
    required this.uid,
    required this.phoneNumber,
    this.displayName,
    this.photoUrl,
    this.username,
    this.lastMessage,
    this.lastMessageTime,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.isDeleted = false,
    this.profileUrl,
  });
}
