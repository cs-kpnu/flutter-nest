import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'full_screen_image.dart'; 
import '../services/audio_manager.dart'; 
import '../services/chat_service.dart';
import '../screens/full_screen_video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // Сам пакет
import 'dart:typed_data'; // Для Uint8List
import 'message_attachment.dart'; // Не забудьте додати імпорт вгорі файлу!
import 'voice_message_player.dart';

class MessageBubble extends StatelessWidget {
  final String messageId;
  final String chatId;
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isDark;
  
  // 🔥 Нові параметри для виділення
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

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '...';
    return DateFormat('HH:mm').format(timestamp.toDate());
  }

  Future<void> _playChatPlaylist(BuildContext context, String currentUrl) async {
    // ... (код плейлиста без змін)
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('type', isEqualTo: 'audio')
          .orderBy('timestamp', descending: false)
          .get();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      List<AudioItem> playlist = snapshot.docs.map((doc) {
        final data = doc.data();
        final bool isMyMessage = data['senderId'] == currentUserId;
        return AudioItem(
          url: data['url'] ?? '',
          fileName: data['fileName'] ?? 'Аудіо',
          artist: isMyMessage ? 'Ви' : 'Співрозмовник',
        );
      }).toList();

      final startIndex = playlist.indexWhere((item) => item.url == currentUrl);
      if (startIndex != -1) {
        AudioManager().playAudio(newPlaylist: playlist, startIndex: startIndex);
      }
    } catch (e) {
      print("Помилка: $e");
    }
  }

  void _showOptions(BuildContext context, String type, String currentText) {
    if (!isMe) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              if (type == 'text')
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
    final type = message['type'] ?? 'text';
    final content = message['text'] ?? '';
    final url = message['url'] ?? '';
    final fileName = message['fileName'] ?? 'Файл';
    final timestamp = message['timestamp'] as Timestamp?;
    final isRead = message['isRead'] ?? false;
    final isEdited = message['isEdited'] ?? false; 

    // Кольори
    final Color bubbleColor;
    if (isSelected) {
      bubbleColor = Colors.blue.withOpacity(0.4); // Колір при виділенні
    } else {
      bubbleColor = isMe
          ? (isDark ? const Color.fromARGB(255, 93, 117, 136) : Colors.blue[600])!
          : (isDark ? const Color.fromARGB(255, 44, 54, 63) : Colors.grey[300])!;
    }
    
    final textColor = (isMe || isDark || isSelected) ? Colors.white : Colors.black;
    final timeColor = (isMe || isDark || isSelected) ? Colors.white70 : Colors.black54;

    Widget messageContent;

    // --- ЛОГІКА ВНУТРІШНЬОГО КОНТЕНТУ (МЕДІА) ---
    // Якщо ми в режимі виділення - всі кліки перехоплює батьківський GestureDetector.
    // Якщо звичайний режим - медіа має свій GestureDetector для відкриття.

    switch (type) {
      case 'image':
        final String heroTag = messageId;
        Widget imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, fit: BoxFit.cover,
            loadingBuilder: (c, child, p) => p == null ? child : SizedBox(width:200, height:200, child: Center(child: CircularProgressIndicator(color: textColor))),
            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 50),
          ),
        );

        if (!isSelectionMode) {
          imageWidget = GestureDetector(
            onTap: () {
              // 🔥 ЗАМІНЯЄМО MaterialPageRoute НА PageRouteBuilder
              Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false, // Дозволяє бачити попередній екран
                  barrierColor: Colors.transparent, // Підкладка має бути прозорою
                  transitionDuration: const Duration(milliseconds: 100), // Швидкість відкриття
                  reverseTransitionDuration: const Duration(milliseconds: 100), // Швидкість закриття (важливо!)
                  pageBuilder: (context, _, __) => FullScreenImageGallery(
                    chatId: chatId,
                    startUrl: url,
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    // Плавна поява
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: imageWidget,
          );
        }
        
        messageContent = Container(
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 200),
          child: imageWidget,
        );
        break;
      
      case 'video':
        // Використовуємо FutureBuilder для завантаження мініатюри
        Widget videoWidget = FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(
            video: url,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 300, // Обмежуємо розмір для економії пам'яті
            quality: 50,    // Середня якість для швидкості
          ),
          builder: (context, snapshot) {
            // 1. Якщо мініатюра завантажилась
            if (snapshot.hasData && snapshot.data != null) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Сама картинка
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      width: 240, // Фіксована ширина для бабла з відео
                      height: 160,
                    ),
                  ),
                  // Іконка Play поверх картинки
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
                  ),
                  // Маленька іконка відео в кутку та ім'я файлу (опціонально)
                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          const Icon(Icons.videocam, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  )
                ],
              );
            } else if (snapshot.hasError) {
              // 2. Якщо помилка (показуємо стару заглушку)
               return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Помилка відео: $fileName', style: TextStyle(color: textColor))),
                ],
              );
            }
            
            // 3. Поки вантажиться (показуємо лоадер)
            return Container(
               width: 240, height: 160,
               decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
               child: Center(child: CircularProgressIndicator(color: textColor)),
            );
          },
        );
        if (!isSelectionMode) {
          videoWidget = GestureDetector(
            onTap: () {
               Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false, // Дозволяє бачити попередній екран
                  barrierColor: Colors.transparent, // 🔥 ВИПРАВЛЕНО: Має бути прозорим!
                  transitionDuration: const Duration(milliseconds: 100), // Швидкість відкриття
                  reverseTransitionDuration: const Duration(milliseconds: 100), // Швидкість закриття (важливо!)
                  pageBuilder: (context, _, __) => FullScreenVideoPlayer(
                    chatId: chatId,
                    startUrl: url,
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: videoWidget,
          );
        }

        messageContent = Container(
          constraints: const BoxConstraints(maxWidth: 240), // Обмеження ширини для відео-бабла
          child: videoWidget
        );
        break;

      case 'audio':
        Widget audioWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audiotrack, size: 30, color: textColor),
            const SizedBox(width: 8),
            Expanded(child: Text('Аудіо: $fileName', style: TextStyle(color: textColor, decoration: TextDecoration.underline))),
          ],
        );

        if (!isSelectionMode) {
          audioWidget = InkWell(
            onTap: () => _playChatPlaylist(context, url),
            child: audioWidget,
          );
        }
        messageContent = audioWidget;
        break;

      case 'voice':
        // 🔥 ВИКОРИСТОВУЄМО НАШ НОВИЙ ПЛЕЄР
        messageContent = VoiceMessagePlayer(
          url: url,
          isMe: isMe,
          // Спробуємо дістати тривалість, якщо ми її зберегли при відправці
          originalDuration: message['duration'] is int ? message['duration'] : null,
        );
        break;

      case 'file':
        // 🔥 ВИКОРИСТОВУЄМО РОЗУМНИЙ ВІДЖЕТ ЗАМІСТЬ ПРОСТОГО ТЕКСТУ
        // Він сам перевірить розширення файлу (.jpg, .mp4, .pdf)
        messageContent = MessageAttachment(
          fileUrl: url,
          fileName: fileName,
          fileType: 'file',
        );
        break;

      default: // text
        messageContent = Text(content, style: TextStyle(color: textColor, fontSize: 16));
    }

    // --- ГОЛОВНИЙ КОНТЕЙНЕР БУЛЬБАШКИ ---
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // 1. Довге натискання -> Вмикає режим виділення
        onLongPress: onToggleSelection,
        
        // 2. Звичайний тап по БУЛЬБАШЦІ (фону):
        onTap: () {
          if (isSelectionMode) {
            // У режимі виділення будь-який тап змінює вибір
            onToggleSelection();
          } else {
            // У звичайному режимі тап по фону (або тексту) відкриває меню
            _showOptions(context, type, content);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          // Додаємо трохи padding, щоб було куди натиснути "біля" картинки
          padding: const EdgeInsets.all(10), 
          decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              messageContent,
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