import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../services/chat_service.dart';
import '../services/audio_manager.dart'; 
import '../widgets/message_bubble.dart'; 
import '../widgets/chat_input.dart';
import '../widgets/mini_audio_player.dart';

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
  
  bool _isUploading = false;
  
  // 🔥 НОВІ ЗМІННІ ДЛЯ МУЛЬТИ-ВИБОРУ
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // --- ЛОГІКА ВИБОРУ ---
  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }

      // Якщо нічого не вибрано, виходимо з режиму
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
    
    // Показуємо діалог підтвердження
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
      // Видаляємо всі вибрані
      for (var id in _selectedMessageIds) {
        await _chatService.deleteMessage(widget.chatId, id);
      }
      _exitSelectionMode();
    }
  }

  // --- СТАНДАРТНІ МЕТОДИ ---
  void _handleSendMessage(String text) {
    _chatService.sendTextMessage(widget.chatId, widget.otherUser['uid'], text);
  }

  Future<void> _handleSendMedia(XFile file, String type) async {
    final size = await file.length();
    if (!await _checkFileSize(size)) return;

    setState(() => _isUploading = true);
    try {
      await _chatService.sendMediaMessage(widget.chatId, widget.otherUser['uid'], file, type);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Помилка: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  final int _maxFileSize = 10 * 1024 * 1024;
  Future<bool> _checkFileSize(int size) async {
      if (size > _maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Файл завеликий! Максимум 10 МБ."),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      return true;
    }

  Future<void> _handleSendFile(PlatformFile file, String type) async {
    if (!await _checkFileSize(file.size)) return;

    setState(() => _isUploading = true);
    try {
      await _chatService.sendFileMessage(widget.chatId, widget.otherUser['uid'], file, type);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Помилка: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
    
    // ❌ ВИДАЛЯЄМО ЦЕЙ РЯДОК (це корінь зла, що викликає лаги)
    // final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
      
      // ✅ 1. ВМИКАЄМО ЦЕ. Нехай Flutter сам піднімає екран.
      resizeToAvoidBottomInset: true, 
      
      body: Stack(
        children: [
          Positioned.fill(
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
  
                return ValueListenableBuilder<String?>(
                  valueListenable: AudioManager().currentUrlNotifier,
                  builder: (context, currentUrl, _) {
                    
                    // ✅ 2. ВИРАХОВУЄМО ТІЛЬКИ ВІДСТУП ДЛЯ ПЛЕЄРА
                    // 80 - це висота ChatInput, 110 - висота плеєра
                    double bottomPadding = 80; 
                    if (currentUrl != null) {
                      bottomPadding += 110; 
                    }

                    return ListView.builder(
                      reverse: true,
                      // Прибираємо bottomInset звідси
                      padding: EdgeInsets.fromLTRB(0, 20, 0, bottomPadding), 
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
                );
              },    
            ),
          ),

          // ШАР 2: Плеєр та Поле вводу
          if (!_isSelectionMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column( // ❌ ПРИБРАЛИ Container з кольором тут
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniAudioPlayer(),
                  
                  // ✅ ПЕРЕНЕСЛИ КОЛІР СЮДИ (Тільки для поля вводу)
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: ChatInput(
                      onSendMessage: _handleSendMessage,
                      onSendMedia: _handleSendMedia,
                      onSendFile: _handleSendFile,
                      isUploading: _isUploading,
                    onSendVoice: (path, duration) {
                        // Викликаємо сервіс (який ми писали раніше)
                        _chatService.sendVoiceMessage(
                          widget.chatId, 
                          widget.otherUser['uid'], 
                          path, 
                          duration
                        );
                      },
                    ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}