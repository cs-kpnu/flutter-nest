import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// 🔥 Імпорти для плеєрів та медіа
import '../screens/full_screen_video_player.dart';
import '../widgets/full_screen_image.dart';
import '../services/audio_manager.dart'; // <--- Додали імпорт AudioManager

class MessageAttachment extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String fileType;

  const MessageAttachment({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
  });

  @override
  State<MessageAttachment> createState() => _MessageAttachmentState();
}

class _MessageAttachmentState extends State<MessageAttachment> {
  bool isDownloading = false;

  // 📂 ЛОГІКА ДЛЯ ДОКУМЕНТІВ (PDF, DOCX...)
  Future<void> _openDocument() async {
    if (isDownloading) return;
    setState(() => isDownloading = true);
    print("📥 Спроба завантажити: ${widget.fileUrl}");
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/${widget.fileName}";
      final file = File(filePath);

      if (!await file.exists()) {
        await Dio().download(widget.fileUrl, filePath);
      }

      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Немає додатка для відкриття: ${result.message}")),
          );
        }
      }
    } catch (e) {
      print("Помилка: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Помилка завантаження")));
      }
    } finally {
      if (mounted) setState(() => isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🖼️ 1. КАРТИНКА -> FullScreenImageGallery
    if (_isImage(widget.fileName)) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenImageGallery(
                chatId: 'temp_view',
                startUrl: widget.fileUrl,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.fileUrl,
            width: 200, height: 200, fit: BoxFit.cover,
            errorBuilder: (_,__,___) => const Icon(Icons.broken_image),
          ),
        ),
      );
    }

    // 🎥 2. ВІДЕО -> FullScreenVideoPlayer
    if (_isVideo(widget.fileName)) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenVideoPlayer(
                chatId: 'temp_view',
                startUrl: widget.fileUrl,
              ),
            ),
          );
        },
        child: Container(
          width: 200, height: 150,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
              Positioned(
                bottom: 8, left: 8,
                child: Text(
                  widget.fileName, 
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🎵 3. АУДІО -> Граємо в AudioManager (В додатку)
    if (_isAudio(widget.fileName)) {
      return GestureDetector(
        onTap: () {
          // Відтворюємо аудіо через наш менеджер
          AudioManager().playAudio(
            newPlaylist: [
              AudioItem(
                url: widget.fileUrl,
                fileName: widget.fileName,
                artist: 'Аудіофайл з чату',
              )
            ],
            startIndex: 0,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1), // Виділяємо кольором
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.music, color: Colors.purple, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).textTheme.bodyLarge?.color
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Натисніть, щоб слухати ▶",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 📄 4. ДОКУМЕНТ -> Скачуємо і відкриваємо (OpenFilex)
    return GestureDetector(
      onTap: _openDocument,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getFileIcon(widget.fileName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).textTheme.bodyLarge?.color
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isDownloading ? "Завантаження..." : "Натисніть, щоб відкрити",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isDownloading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.download_rounded, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // 👇 Хелпери визначення типу
  bool _isImage(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext);
  }

  bool _isVideo(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }

  // ✅ Додав перевірку аудіо
  bool _isAudio(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'].contains(ext);
  }

  Widget _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    switch (ext) {
      case 'pdf': icon = FontAwesomeIcons.filePdf; color = Colors.red; break;
      case 'doc': case 'docx': icon = FontAwesomeIcons.fileWord; color = Colors.blue; break;
      case 'xls': case 'xlsx': icon = FontAwesomeIcons.fileExcel; color = Colors.green; break;
      case 'ppt': case 'pptx': icon = FontAwesomeIcons.filePowerpoint; color = Colors.orange; break;
      case 'zip': case 'rar': icon = FontAwesomeIcons.fileZipper; color = Colors.amber; break;
      case 'txt': icon = FontAwesomeIcons.fileLines; color = Colors.grey; break;
      default: icon = FontAwesomeIcons.file; color = Colors.grey;
    }
    return FaIcon(icon, color: color, size: 30);
  }
}