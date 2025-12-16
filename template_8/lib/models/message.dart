import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final String? type;
  final String? fileUrl;   
  final String? fileName;
  final bool isRead; // 🔥 Нове поле

  Message({
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.type = 'text',
    this.fileUrl,
    this.fileName,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'isRead': isRead,
    };
  }
}