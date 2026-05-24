class UserEntity {
  final String uid;
  final String phoneNumber;
  final String? displayName;
  final String? photoUrl;

  UserEntity({
    required this.uid,
    required this.phoneNumber,
    this.displayName,
    this.photoUrl,
  });
}
