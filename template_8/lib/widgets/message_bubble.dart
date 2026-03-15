import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';

class MessageBubble extends StatelessWidget {
  final String messageId;
  final String chatId;
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDark;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  MessageBubble({
    super.key,
    required this.messageId,
    required this.chatId,
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
  });

  final ChatService _chatService = ChatService();

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '...';
    return DateFormat('HH:mm').format(timestamp.toDate());
  }

  void _showOptions(BuildContext context, String currentText) {
    if (!isMe) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Редагувати'),
                onTap: () {
                  Navigator.pop(ctx); 
                  _showEditDialog(context, currentText);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Видалити', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Редагувати повідомлення"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Введіть новий текст"),
          maxLines: null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Скасувати")),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _chatService.updateMessage(chatId, messageId, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text("Зберегти"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Видалити повідомлення?"),
        content: const Text("Цю дію не можна скасувати."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ні")),
          TextButton(
            onPressed: () {
              _chatService.deleteMessage(chatId, messageId);
              Navigator.pop(ctx);
            },
            child: const Text("Так, видалити", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = message['text'] ?? '';
    final timestamp = message['timestamp'] as Timestamp?;
    final isRead = message['isRead'] ?? false;
    final isEdited = message['isEdited'] ?? false; 

    final Color bubbleColor;
    if (isSelected) {
      bubbleColor = Colors.blue.withOpacity(0.4);
    } else {
      bubbleColor = isMe
          ? (isDark ? const Color.fromARGB(255, 93, 117, 136) : Colors.blue[600])!
          : (isDark ? const Color.fromARGB(255, 44, 54, 63) : Colors.grey[300])!;
    }
    
    final textColor = (isMe || isDark || isSelected) ? Colors.white : Colors.black;
    final timeColor = (isMe || isDark || isSelected) ? Colors.white70 : Colors.black54;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onToggleSelection,
        onTap: () {
          if (isSelectionMode) {
            onToggleSelection();
          } else {
            _showOptions(context, content);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(10), 
          decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(content, style: TextStyle(color: textColor, fontSize: 16)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdited) ...[
                     Icon(Icons.edit, size: 12, color: timeColor),
                     const SizedBox(width: 4),
                  ],
                  Text(_formatTime(timestamp), style: TextStyle(fontSize: 10, color: timeColor)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(isRead ? Icons.done_all : Icons.check, size: 16, color: isRead ? (isDark ? Colors.lightBlueAccent : Colors.white) : timeColor),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}