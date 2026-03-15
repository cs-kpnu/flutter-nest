import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; 
import 'package:googleapis_auth/auth_io.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? _currentActiveChatId;

  static void setActiveChatId(String? chatId) {
    _currentActiveChatId = chatId;
    print('📱 Активний чат: $_currentActiveChatId');
  }

  Future<void> sendTextMessage(String chatId, String otherUserId, String text) async {
    await _addMessage(chatId, otherUserId, {'text': text}, 'text', text);
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