import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/chat_service.dart';
import '../widgets/message_bubble.dart'; 
import '../widgets/chat_input.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> otherUser;

  const ChatScreen({super.key, required this.chatId, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _chatService = ChatService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }

      if (_selectedMessageIds.isEmpty) {
        _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _deleteSelectedMessages() async {
    final count = _selectedMessageIds.length;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Видалити $count повідомлень?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Ні")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Видалити", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var id in _selectedMessageIds) {
        await _chatService.deleteMessage(widget.chatId, id);
      }
      _exitSelectionMode();
    }
  }

  void _handleSendMessage(String text) {
    _chatService.sendTextMessage(widget.chatId, widget.otherUser['uid'], text);
  }

  ImageProvider? _getAvatar(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      if (url.startsWith('http')) return NetworkImage(url);
      return MemoryImage(base64Decode(url));
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserActiveInChat(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserActiveInChat(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setUserActiveInChat(false);
    } else if (state == AppLifecycleState.resumed) {
      _setUserActiveInChat(true);
    }
  }

  Future<void> _setUserActiveInChat(bool isActive) async {
    final currentUserId = _currentUser!.uid;
    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('activeUsers')
        .doc(currentUserId)
        .set({
          'isActive': isActive,
          'chatId': isActive ? widget.chatId : null,
          'timestamp': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.otherUser['photoUrl'] as String?;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode)
          : null,
        title: _isSelectionMode
          ? Text("${_selectedMessageIds.length} вибрано")
          : Row(
              children: [
                CircleAvatar(
                  backgroundImage: _getAvatar(photoUrl),
                  radius: 18,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(widget.otherUser['username'][0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 10),
                Text(widget.otherUser['username']),
              ],
            ),
        actions: [
          if (_isSelectionMode)
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteSelectedMessages),
        ],
      ),
      resizeToAvoidBottomInset: true, 
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
  
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 10), 
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final messageId = docs[index].id; 
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUser!.uid;

                    if (!isMe && !(data['isRead'] ?? false)) {
                      Future.delayed(Duration.zero, () {
                        _chatService.markMessageAsRead(widget.chatId, messageId);
                      });
                    }
                  
                    final isSelected = _selectedMessageIds.contains(messageId);

                    return MessageBubble(
                      messageId: messageId,
                      chatId: widget.chatId,
                      message: data,
                      isMe: isMe,
                      isDark: isDark,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      onToggleSelection: () => _toggleSelection(messageId),
                    );
                  },
                );
              },    
            ),
          ),
          if (!_isSelectionMode)
            ChatInput(
              onSendMessage: _handleSendMessage,
            ),
        ],
      ),
    );
  }
}