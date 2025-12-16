import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe; // Щоб підлаштувати колір під фон бульбашки
  final int? originalDuration; // Тривалість у секундах (якщо є)

  const VoiceMessagePlayer({
    super.key,
    required this.url,
    required this.isMe,
    this.originalDuration,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    // Якщо тривалість передали ззовні - показуємо її одразу
    if (widget.originalDuration != null) {
      _duration = Duration(seconds: widget.originalDuration!);
    }
  }

  Future<void> _initPlayer() async {
    setState(() => _isLoading = true);
    try {
      // 1. Завантажуємо URL
      await _player.setUrl(widget.url);
      _isInitialized = true;

      // 2. Підписуємося на події
      _playerStateSub = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            // Якщо дограло до кінця - скидаємо
            if (state.processingState == ProcessingState.completed) {
              _player.stop();
              _player.seek(Duration.zero);
              _isPlaying = false;
            }
          });
        }
      });

      _positionSub = _player.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      });

      _durationSub = _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _duration = d);
      });

      // 3. Запускаємо
      await _player.play();

    } catch (e) {
      print("Помилка аудіо: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlay() async {
    if (!_isInitialized) {
      await _initPlayer();
    } else {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    }
  }

  Future<void> _seek(double value) async {
    if (!_isInitialized) return;
    final position = Duration(milliseconds: value.toInt());
    await _player.seek(position);
  }

  @override
  void dispose() {
    // Обов'язково чистимо ресурси
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // Кольори залежать від того, чиє це повідомлення (темне на світлому або навпаки)
    final foregroundColor = widget.isMe ? Colors.white : Colors.black87;
    final sliderActiveColor = widget.isMe ? Colors.white : Colors.blue;
    final sliderInactiveColor = widget.isMe ? Colors.white38 : Colors.grey[400];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      width: 240, // Фіксована ширина плеєра
      child: Row(
        children: [
          // 1. КНОПКА PLAY / LOADING
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: foregroundColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foregroundColor,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                      color: foregroundColor,
                      size: 24,
                    ),
            ),
          ),

          const SizedBox(width: 8),

          // 2. ТАЙМЛАЙН (Slider)
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                activeTrackColor: sliderActiveColor,
                inactiveTrackColor: sliderInactiveColor,
                thumbColor: sliderActiveColor,
              ),
              child: Slider(
                min: 0.0,
                max: _duration.inMilliseconds.toDouble() > 0 
                    ? _duration.inMilliseconds.toDouble() 
                    : 1.0,
                value: _position.inMilliseconds.toDouble().clamp(
                      0.0, 
                      _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0
                    ),
                onChanged: (val) {
                  _seek(val);
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 3. ЧАС (MM:SS)
          Text(
            _formatDuration(_position.inMilliseconds > 0 ? _position : _duration),
            style: TextStyle(
              fontSize: 12,
              color: foregroundColor,
              fontFeatures: const [FontFeature.tabularFigures()], // Щоб цифри не стрибали
            ),
          ),
        ],
      ),
    );
  }
}