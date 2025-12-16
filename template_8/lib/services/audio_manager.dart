import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

// 1. Модель даних для аудіо
class AudioItem {
  final String url;
  final String fileName;
  final String? artist;
  final String? imageUrl;

  AudioItem({
    required this.url, 
    required this.fileName, 
    this.artist, 
    this.imageUrl
  });
}

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  final AudioPlayer _player = AudioPlayer();
  
  // 🔥 1. ДОДАЄМО ЗАПОБІЖНИК
  bool _isBusy = false;

  final ValueNotifier<List<AudioItem>> playlistNotifier = ValueNotifier([]);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> currentFileNameNotifier = ValueNotifier<String>('');
  final ValueNotifier<String?> currentUrlNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);

  AudioManager._internal() {
    // ... (весь код конструктора залишається без змін) ...
    _player.playerStateStream.listen((playerState) {
      final processingState = playerState.processingState;
      isPlayingNotifier.value = playerState.playing;

      if (processingState == ProcessingState.loading || 
          processingState == ProcessingState.buffering) {
        isLoadingNotifier.value = true;
      } else {
        isLoadingNotifier.value = false;
      }
    });

    _player.positionStream.listen((pos) => positionNotifier.value = pos);
    _player.durationStream.listen((dur) => durationNotifier.value = dur ?? Duration.zero);

    _player.currentIndexStream.listen((index) {
      if (index != null && playlistNotifier.value.isNotEmpty) {
        currentIndexNotifier.value = index;
        if (index < playlistNotifier.value.length) {
          final item = playlistNotifier.value[index];
          currentFileNameNotifier.value = item.fileName;
          currentUrlNotifier.value = item.url; 
        }
      }
    });
  }

  Future<void> playAudio({
    required List<AudioItem> newPlaylist,
    required int startIndex,
  }) async {
    if (newPlaylist.isEmpty) return;
    
    // 🔥 2. ЯКЩО ПЛЕЄР ЗАЙНЯТИЙ — ВИХОДИМО
    if (_isBusy) return;
    _isBusy = true;

    try {
      isLoadingNotifier.value = true;
      
      playlistNotifier.value = newPlaylist;
      currentIndexNotifier.value = startIndex;
      
      currentFileNameNotifier.value = newPlaylist[startIndex].fileName;
      currentUrlNotifier.value = newPlaylist[startIndex].url;

      final audioSources = newPlaylist.map((item) => AudioSource.uri(
        Uri.parse(item.url),
        tag: item,
      )).toList();

      final playlist = ConcatenatingAudioSource(children: audioSources);

      await _player.setAudioSource(
        playlist,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );

      await _player.play();
      
    } catch (e) {
      print("⛔ AUDIO ERROR: $e");
      isLoadingNotifier.value = false;
    } finally {
      // 🔥 3. ЗВІЛЬНЯЄМО ПЛЕЄР
      _isBusy = false;
    }
  }

  // 🔥 4. ЗАХИЩАЄМО ІНШІ МЕТОДИ
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    // 1. Беремо наші дані (список та індекс)
    final playlist = playlistNotifier.value;
    final currentIndex = currentIndexNotifier.value;

    // 2. Перевіряємо вручну: якщо ми не на останньому треку
    if (currentIndex < playlist.length - 1) {
      // 3. Примусово перемикаємо на (поточний + 1)
      await _player.seek(Duration.zero, index: currentIndex + 1);
    }
  }

  // 🔥 ОНОВЛЕНИЙ МЕТОД PREVIOUS
  Future<void> previous() async {
    // 1. Беремо поточний індекс
    final currentIndex = currentIndexNotifier.value;

    // 2. Перевіряємо вручну: якщо ми не на першому треку
    if (currentIndex > 0) {
      // 3. Примусово перемикаємо на (поточний - 1)
      await _player.seek(Duration.zero, index: currentIndex - 1);
    }
  }
  
  Future<void> playVoiceMessage(String url) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      isLoadingNotifier.value = true;

      // 1. Очищаємо плейлист музики, щоб плеєр "забув" про треки
      playlistNotifier.value = [];
      currentIndexNotifier.value = 0;
      
      // 2. Встановлюємо дані для UI
      currentFileNameNotifier.value = "Голосове повідомлення";
      currentUrlNotifier.value = url;

      // 3. Завантажуємо ТІЛЬКИ ЦЕЙ файл
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url)),
        initialPosition: Duration.zero,
      );

      await _player.play();
    } catch (e) {
      print("Error playing voice: $e");
      isLoadingNotifier.value = false;
    } finally {
      _isBusy = false;
    }
  }
  
  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    currentUrlNotifier.value = null;
    isPlayingNotifier.value = false;
  }
}