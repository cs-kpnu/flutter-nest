//
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(XFile, String) onSendMedia; 
  final Function(PlatformFile, String) onSendFile;
  final Function(String path, int duration) onSendVoice; 
  final bool isUploading;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onSendMedia,
    required this.onSendFile,
    required this.onSendVoice,
    this.isUploading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  
  // Кнопка відправки тексту
  bool _showSendButton = false;
  
  // --- Змінні для запису ---
  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;
  
  // Стани
  bool _isRecording = false;      // Чи йде запис
  bool _isLocked = false;         // Чи заблоковано свайпом вгору
  bool _showStickySendButton = false; // Чи показувати кнопку "надіслати" (режим hands-free)

  // Координати для трекінгу свайпу
  double _startY = 0.0;

  DateTime? _recordStartTime;
  StreamSubscription? _recorderSubscription;
  String _recordDuration = "00:00";

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _initRecorder();

    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (_showSendButton != hasText) {
        setState(() {
          _showSendButton = hasText;
        });
      }
    });
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();
    await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isRecorderInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_recorder != null) {
      _recorder!.closeRecorder();
      _recorder = null;
    }
    _recorderSubscription?.cancel();
    super.dispose();
  }

  // --- ЛОГІКА ЗАПИСУ ---
  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;

    // Миттєвий візуальний відгук (щоб не було затримок)
    if (mounted) {
      setState(() {
        _isRecording = true;
        _isLocked = false;
        _showStickySendButton = false;
        _recordDuration = "00:00";
      });
    }

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _resetState();
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder!.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
      );

      _recorderSubscription = _recorder!.onProgress!.listen((e) {
        final duration = e.duration;
        if (mounted) {
          setState(() {
            _recordDuration = "${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
          });
        }
      });

      if (mounted) {
        setState(() {
          _recordStartTime = DateTime.now();
        });
      }

    } catch (e) {
      print("Error starting record: $e");
      _resetState();
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    // Якщо ми вже не пишемо і не в режимі hands-free — ігноруємо
    if (!_isRecording && !_showStickySendButton) return;

    try {
      String? path;
      if (_recorder!.isRecording) {
        path = await _recorder!.stopRecorder();
      }
      _recorderSubscription?.cancel();
      
      final startTime = _recordStartTime ?? DateTime.now();
      final duration = DateTime.now().difference(startTime);

      // Скидаємо UI гарантовано
      _resetState();

      if (cancel) {
        print("🗑️ Запис скасовано");
        if (path != null) File(path).delete().ignore();
        return;
      }

      // Якщо це був просто випадковий "клік" (менше 0.5 с), не відправляємо
      if (duration.inMilliseconds < 500) return;

      if (path != null) {
        widget.onSendVoice(path, duration.inSeconds);
      }
    } catch (e) {
      print("Error stopping record: $e");
      _resetState();
    }
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _showStickySendButton = false;
        _recordDuration = "00:00";
      });
    }
  }

  // --- МЕТОДИ ДЛЯ LISTENER (ВИРІШУЄ ПРОБЛЕМУ ЗАВИСАННЯ) ---
  
  void _onPointerDown(PointerDownEvent event) {
    _startY = event.position.dy; // Запам'ятовуємо де натиснули
    _startRecording();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isRecording || _isLocked) return;

    // Рахуємо різницю: поточна позиція - стартова
    // Якщо тягнемо вгору, значення буде від'ємним
    final diff = event.position.dy - _startY;

    // Якщо потягнули вгору більше ніж на 60 пікселів - блокуємо
    if (diff < -60) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isLocked) {
      // Якщо ми заблокували запис ("замок"), то відпускання пальця
      // має просто переключити кнопку на "Надіслати" (Sticky mode)
      setState(() {
        _showStickySendButton = true;
      });
    } else {
      // Якщо НЕ блокували - зупиняємо і відправляємо
      _stopRecording();
    }
  }

  // --- МЕНЮ ВКЛАДЕНЬ (З КНОПКОЮ АУДІО) ---
  void _showAttachmentOptions() { 
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Фото'),
              onTap: () { Navigator.pop(ctx); _pickMedia(ImageSource.gallery, 'image'); },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Відео'),
              onTap: () { Navigator.pop(ctx); _pickMedia(ImageSource.gallery, 'video'); },
            ),
            // ✅ КНОПКА АУДІО ПОВЕРНУТА
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: const Text('Аудіо'),
              onTap: () { Navigator.pop(ctx); _pickFile(FileType.audio, 'audio'); },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Файл'),
              onTap: () { Navigator.pop(ctx); _pickFile(FileType.any, 'file'); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source, String type) async {
    final picker = ImagePicker();
    final XFile? file = type == 'video' ? await picker.pickVideo(source: source) : await picker.pickImage(source: source, imageQuality: 50, maxWidth: 1920);
    if (file != null) widget.onSendMedia(file, type);
  }

  Future<void> _pickFile(FileType fileType, String msgType) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: fileType);
      if (result != null && result.files.single.path != null) widget.onSendFile(result.files.single, msgType);
    } catch (e) { print('Error: $e'); }
  }

  void _send() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSendMessage(_controller.text.trim());
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    // Логіка показу кнопок
    bool showTextSendButton = _showSendButton; 
    bool showVoiceSendButton = _showStickySendButton;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isUploading) const LinearProgressIndicator(),
        
        // Підказка "Потягніть вгору" (тільки коли тримаємо і ще не заблокували)
        if (_isRecording && !_isLocked && !_showStickySendButton)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(Icons.keyboard_arrow_up, color: Colors.grey[400]),
                Text("Потягніть вгору для блокування", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: isDark ? Colors.white70 : Colors.grey[700]),
                onPressed: widget.isUploading || _isRecording ? null : _showAttachmentOptions,
              ),
              
              Expanded(
                child: (_isRecording || _showStickySendButton)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          // Блимаючий індикатор
                          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            (_isLocked || _showStickySendButton) ? "Запис (вільні руки)" : "Запис...", 
                            style: TextStyle(
                              color: (_isLocked || _showStickySendButton) ? primaryColor : Colors.red, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                          const Spacer(),
                          Text(_recordDuration, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          
                          // Кнопка скасування (смітник)
                          if (_isLocked || _showStickySendButton) 
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _stopRecording(cancel: true),
                            ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      
                      // 🔥🔥🔥 НОВІ НАЛАШТУВАННЯ ТУТ 🔥🔥🔥
                      keyboardType: TextInputType.multiline, // Дозволяє багато рядків
                      maxLines: 5, // Росте до 5 рядків, потім скролиться
                      minLines: 1, // Початкова висота
                      textInputAction: TextInputAction.newline, // Кнопка Enter робить новий рядок
                      
                      decoration: const InputDecoration(
                        hintText: "Повідомлення...", 
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), // Трохи відступів для краси
                      ),
                      
                      // ❌ Цей рядок треба видалити, щоб Enter не відправляв повідомлення:
                      // onSubmitted: (_) => _send(), 
                    ),
              ),

              // 🔥 ОСНОВНА ЛОГІКА КНОПОК 🔥
              if (showTextSendButton)
                // 1. Кнопка відправки ТЕКСТУ
                IconButton(
                  icon: Icon(Icons.send, color: primaryColor),
                  onPressed: _send,
                )
              else if (showVoiceSendButton)
                // 2. Кнопка відправки ГОЛОСУ (після блокування/hands-free)
                GestureDetector(
                  onTap: () => _stopRecording(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: Colors.white, size: 28),
                  ),
                )
              else
                // 3. МІКРОФОН (З Listener замість GestureDetector)
                Listener(
                  onPointerDown: _onPointerDown, // Торкнувся - старт
                  onPointerMove: _onPointerMove, // Рух - перевірка на лок
                  onPointerUp: _onPointerUp,     // Відпустив - стоп або фіксація
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                       color: _isRecording ? Colors.red.withOpacity(0.2) : Colors.transparent,
                       shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isLocked ? Icons.lock : (_isRecording ? Icons.mic_none : Icons.mic), 
                      color: _isRecording ? (_isLocked ? primaryColor : Colors.red) : (isDark ? Colors.white70 : Colors.grey[700]),
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}