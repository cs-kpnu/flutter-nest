//
import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/services.dart'; 
import 'package:googleapis_auth/auth_io.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final String _cloudName = "dsn4k0hsl"; 
  final String _uploadPreset = "chat_upload";

  late CloudinaryPublic _cloudinary;

  ChatService() {
    _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  static String? _currentActiveChatId;

  static void setActiveChatId(String? chatId) {
    _currentActiveChatId = chatId;
    print('📱 Активний чат: $_currentActiveChatId');
  }

  Future<void> sendVoiceMessage(String chatId, String otherUserId, String filePath, int durationSeconds) async {
    final url = await _uploadFileToCloudinary(
      filePath, 
      resourceType: CloudinaryResourceType.Video, 
      fileName: 'voice_message.m4a'
    );

    if (url != null) {
      await _addMessage(
        chatId, 
        otherUserId, 
        {
          'url': url, 
          'fileName': 'Голосове повідомлення', 
          'duration': durationSeconds 
        }, 
        'voice', 
        '🎤 Голосове повідомлення'
      );
    }
  }

  Future<void> sendTextMessage(String chatId, String otherUserId, String text) async {
    await _addMessage(chatId, otherUserId, {'text': text}, 'text', text);
  }

  Future<void> sendMediaMessage(String chatId, String otherUserId, XFile file, String type) async {
    final resourceType = type == 'video' 
        ? CloudinaryResourceType.Video 
        : CloudinaryResourceType.Image;

    final url = await _uploadFileToCloudinary(
      file.path, 
      resourceType: resourceType,
      fileName: file.name
    );

    if (url != null) {
      await _addMessage(chatId, otherUserId, {'url': url, 'fileName': file.name}, type, type == 'video' ? '🎥 Відео' : '📷 Фото');
    }
  }

  Future<void> sendFileMessage(String chatId, String otherUserId, PlatformFile file, String type) async {
    if (file.path == null) {
        print("⛔ Помилка: шлях до файлу не знайдено");
        return;
    }

    final resourceType = type == 'audio' 
        ? CloudinaryResourceType.Video 
        : CloudinaryResourceType.Raw;

    final url = await _uploadFileToCloudinary(
      file.path!, 
      resourceType: resourceType,
      fileName: file.name
    );

    if (url != null) {
      await _addMessage(chatId, otherUserId, {'url': url, 'fileName': file.name, 'size': file.size}, type, type == 'audio' ? '🎵 Аудіо' : '📎 Файл');
    }
  }

  Future<String?> _uploadFileToCloudinary(String filePath, {required CloudinaryResourceType resourceType, String? fileName}) async {
    try {
      CloudinaryResourceType finalType = resourceType;
      bool isAudio = false;
      String extension = '';

      if (fileName != null) {
        final lowerName = fileName.toLowerCase();
        if (lowerName.endsWith('.mp3') || lowerName.endsWith('.wav') || 
            lowerName.endsWith('.m4a') || lowerName.endsWith('.aac')) {
          isAudio = true;
          finalType = CloudinaryResourceType.Auto;
          if (fileName.contains('.')) {
             extension = fileName.substring(fileName.lastIndexOf('.'));
          }
        }
      }

      String identifier;
      if (isAudio) {
        identifier = 'audio_${DateTime.now().millisecondsSinceEpoch}$extension';
      } else {
        identifier = fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
      }

      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: finalType,
          folder: 'chat_uploads',
          identifier: identifier,
        ),
      );
      
      return response.secureUrl;
    } catch (e) {
      print('⛔ Cloudinary Exception: $e');
      return null;
    }
  }

  Future<void> _addMessage(String chatId, String otherUserId, Map<String, dynamic> data, String type, String summary) async {
    final currentUserId = _auth.currentUser!.uid;
    
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      ...data,
    });
    
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUserId, otherUserId],
      'lastMessage': summary,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    await _sendPushNotification(otherUserId, summary, chatId);
  }

  final String _projectId = "temp8-80d19"; 

  Future<void> _sendPushNotification(String receiverId, String messageBody, String chatId) async {
    final activeUserDoc = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('activeUsers')
        .doc(receiverId)
        .get();
    
    final isActive = activeUserDoc.data()?['isActive'] ?? false;
    final activeInChatId = activeUserDoc.data()?['chatId'];
    
    if (isActive && activeInChatId == chatId) return;

    try {
      final userDoc = await _firestore.collection('users').doc(receiverId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken == null) return;

      final currentUserId = _auth.currentUser!.uid;
      final senderDoc = await _firestore.collection('users').doc(currentUserId).get();
      final senderName = senderDoc.data()?['username'] ?? 'Нове повідомлення';

      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);
      
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);

      final notificationData = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': senderName,
            'body': messageBody,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'chat',
            'chatId': chatId, 
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'high_importance_channel',
            }
          }
        }
      };

      final url = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      
      await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationData),
      );

      client.close();
    } catch (e) {
      print('⛔ PUSH ERROR: $e');
    }
  }

  Future<void> markMessageAsRead(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({'isRead': true});
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
  }

  Future<void> updateMessage(String chatId, String messageId, String newText) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': newText,
      'isEdited': true,
    });
  }
}