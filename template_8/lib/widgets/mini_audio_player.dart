import 'package:flutter/material.dart';
import 'dart:ui'; 
import '../services/audio_manager.dart'; 
import 'package:flutter/physics.dart'; 

class MiniAudioPlayer extends StatefulWidget {
  const MiniAudioPlayer({super.key});
  
  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  final double _minHeight = 110.0;
  final AudioManager _audioManager = AudioManager();
  bool _isDragging = false;      // Чи тягне зараз користувач повзунок?
  double _dragValue = 0.0;       // Тимчасове значення повзунка
  
  // 🔥 ФІКС 1: Прапорець, щоб знати, що ми саме зараз відкриваємо плеєр
  bool _isExpanding = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), 
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // --- ФІКС 2: Розумне згортання ---
  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    
    // Якщо клавіатура відкрилась і плеєр розгорнутий
    if (bottomInset > 0.0 && _controller.value > 0.1 && !_isExpanding) {
      
      // 🔥 ВИПРАВЛЕННЯ:
      // Використовуємо 200-250 мс. Це стандартна швидкість анімації клавіатури iOS/Android.
      // Curves.easeOut робить рух природним (швидкий початок, плавний кінець).
      _controller.animateTo(
        0.0, 
        duration: const Duration(milliseconds: 100), // Трохи швидше за клавіатуру, щоб не було overflow
        curve: Curves.easeOut, 
      );
    }
    super.didChangeMetrics();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inMinutes}:$twoDigitSeconds";
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxHeight) {
    double range = maxHeight - _minHeight;
    _controller.value -= details.primaryDelta! / range;
  }

  void _handleDragEnd(DragEndDetails details, double maxHeight) {
    final double velocity = details.primaryVelocity ?? 0;
    double target;
    
    if (velocity < -500 || (velocity <= 0 && _controller.value > 0.4)) {
      target = 1.0; 
    } else if (velocity > 500 || (velocity >= 0 && _controller.value < 0.6)) {
      target = 0.0; 
    } else {
      target = _controller.value > 0.5 ? 1.0 : 0.0;
    }

    if (target == 1.0) {
      // Якщо тягнемо вверх - ховаємо клавіатуру
      FocusScope.of(context).unfocus();
    }

    final simulation = SpringSimulation(
      const SpringDescription(mass: 1.0, stiffness: 170.0, damping: 20.0),
      _controller.value, 
      target,            
      -velocity / (maxHeight - _minHeight), 
    );

    _controller.animateWith(simulation);
  }

  Widget _buildCurrentTrackInfo(Color primaryColor) {
    return ValueListenableBuilder<List<AudioItem>>(
      valueListenable: _audioManager.playlistNotifier,
      builder: (context, playlist, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _audioManager.currentIndexNotifier,
          builder: (context, index, _) {
            final item = (playlist.isNotEmpty && index < playlist.length) ? playlist[index] : null;
            
            return Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.music_note, size: 28, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item?.fileName ?? '...',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        item?.artist ?? '...',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final double maxPlayerHeight = screenHeight * 0.60; 

    return ValueListenableBuilder<String?>(
      valueListenable: _audioManager.currentUrlNotifier,
      builder: (context, url, child) {
        if (url == null) {
          if (_controller.value > 0) _controller.value = 0;
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final currentPlayerHeight = lerpDouble(_minHeight, maxPlayerHeight, _controller.value)!;
            final miniOpacity = 1.0 - Interval(0.0, 0.3, curve: Curves.easeOut).transform(_controller.value);
            final expandedOpacity = Interval(0.3, 1.0, curve: Curves.easeIn).transform(_controller.value);
            
            final double totalContainerHeight = _controller.value > 0.01 ? screenHeight : _minHeight;

            return SizedBox(
              height: totalContainerHeight,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // TAP OUTSIDE (Згортання)
                  if (_controller.value > 0.01)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent, 
                        onTap: () {
                          _controller.reverse();
                        },
                        child: Container(
                          // ❌ БУЛО: Colors.black.withOpacity(0.01 * _controller.value) -> це 1% прозорості (майже нічого)
                          
                          // ✅ СТАЛО: 0.7 (70% затемнення при повному відкритті)
                          color: Colors.black.withOpacity(0.7 * _controller.value), 
                        ),
                      ),
                    ),

                  // САМ ПЛЕЄР
                  GestureDetector(
                    onVerticalDragUpdate: (details) => _handleDragUpdate(details, maxPlayerHeight),
                    onVerticalDragEnd: (details) => _handleDragEnd(details, maxPlayerHeight),
                    onTap: () async {
                      if (_controller.value < 0.1) {
                        // 🔥 ФІКС 3: ЛОГІКА ВІДКРИТТЯ
                        
                        // 1. Ставимо прапорець, що ми відкриваємось (щоб didChangeMetrics не закрив нас)
                        _isExpanding = true;
                        
                        // 2. Ховаємо клавіатуру
                        FocusScope.of(context).unfocus();
                        
                        // 3. ЧЕКАЄМО поки клавіатура сховається (це прибере Overflow!)
                        // Клавіатура зазвичай ховається за 200-300мс
                        await Future.delayed(const Duration(milliseconds: 300));
                        
                        // 4. Тепер, коли місця багато, відкриваємо плеєр
                        if (mounted) {
                           await _controller.animateTo(1.0, curve: Curves.easeOutBack, duration: const Duration(milliseconds: 600));
                           // Анімація завершилась, знімаємо прапорець
                           _isExpanding = false;
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: currentPlayerHeight, 
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C363F) : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Expanded Player
                          Positioned.fill(
                            child: Opacity(
                              opacity: expandedOpacity,
                              child: IgnorePointer(
                                ignoring: expandedOpacity < 0.1,
                                child: RepaintBoundary(
                                  child: _buildExpandedView(context, primaryColor, url),
                                ),
                              ),
                            ),
                          ),

                          // Mini Player
                          Positioned(
                            top: 0, left: 0, right: 0,
                            height: _minHeight,
                            child: Opacity(
                              opacity: miniOpacity,
                              child: IgnorePointer(
                                ignoring: miniOpacity < 0.1,
                                child: RepaintBoundary(
                                  child: _buildMiniView(context, primaryColor, url),
                                ),
                              ),
                            ),
                          ),

                          // Handle
                          if (_controller.value > 0.05)
                            Positioned(
                              top: 10, left: 0, right: 0,
                              child: Center(
                                child: Opacity(
                                  opacity: _controller.value,
                                  child: Container(
                                    width: 40, height: 5,
                                    decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- MINIFIED VIEW ---
  Widget _buildMiniView(BuildContext context, Color primaryColor, String url) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.music_note, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _audioManager.currentFileNameNotifier,
                  builder: (context, name, _) => Text(
                    name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _buildPlayButton(primaryColor, 32),
              IconButton(icon: const Icon(Icons.close), onPressed: () => _audioManager.stop()),
            ],
          ),
          const SizedBox(height: 4),
          _buildProgressBar(context, primaryColor, isMini: true),
        ],
      ),
    );
  }

  // --- EXPANDED VIEW ---
  Widget _buildExpandedView(BuildContext context, Color primaryColor, String url) {
    const double headerHeight = 60.0;
    const double controlsHeight = 200.0;

    return Stack(
      children: [
        // Header
        Positioned(
          top: 0, left: 0, right: 0, height: headerHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                      onPressed: () => _controller.reverse(),
                    ),
                    const Text('Плейлист', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),

        // Controls
        Positioned(
          bottom: 0, left: 0, right: 0, height: controlsHeight,
          child: Container(
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCurrentTrackInfo(primaryColor),
                        const SizedBox(height: 8),
                        _buildProgressBar(context, primaryColor, isMini: false),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded),
                              iconSize: 40,
                              onPressed: () => _audioManager.previous(),
                            ),
                            const SizedBox(width: 15),
                            Container(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor),
                              child: _buildPlayButton(Colors.white, 45, padding: 12),
                            ),
                            const SizedBox(width: 15),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded),
                              iconSize: 40,
                              onPressed: () => _audioManager.next(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Playlist
        Positioned(
          top: headerHeight,
          bottom: controlsHeight,
          left: 0, right: 0,
          child: ValueListenableBuilder<List<AudioItem>>(
            valueListenable: _audioManager.playlistNotifier,
            builder: (context, playlist, _) {
              if (playlist.isEmpty) return const Center(child: Text("Список порожній"));

              return ValueListenableBuilder<int>(
                valueListenable: _audioManager.currentIndexNotifier,
                builder: (context, currentIndex, _) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final item = playlist[index];
                      final isCurrent = index == currentIndex;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: isCurrent ? primaryColor.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isCurrent ? Icons.equalizer : Icons.music_note,
                            color: isCurrent ? primaryColor : Colors.grey,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.fileName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? primaryColor : null,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(item.artist ?? 'Невідомий', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        onTap: () {
                          _audioManager.playAudio(newPlaylist: playlist, startIndex: index);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton(Color iconColor, double size, {double padding = 0}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _audioManager.isLoadingNotifier,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return SizedBox(
            width: size + padding * 2, 
            height: size + padding * 2, 
            child: const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(color: Colors.grey))
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: _audioManager.isPlayingNotifier,
          builder: (context, isPlaying, _) {
            return IconButton(
              padding: EdgeInsets.all(padding),
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: size,
              color: iconColor,
              onPressed: () {
                 if (isPlaying) {
                   _audioManager.pause(); 
                 } else {
                   _audioManager.resume(); 
                 }
              },
            );
          },
        );
      },
    );
  }

  //
  //
  Widget _buildProgressBar(BuildContext context, Color primaryColor, {required bool isMini}) {
    return Row(
      children: [
        // Текстовий час зліва
        ValueListenableBuilder<Duration>(
          valueListenable: _audioManager.positionNotifier,
          builder: (context, position, _) {
            // Якщо тягнемо — показуємо час, до якого дотягнули
            final displayTime = _isDragging 
                ? Duration(milliseconds: _dragValue.toInt()) 
                : position;
            
            return Text(
              _formatDuration(displayTime),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            );
          },
        ),
        
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: isMini ? 2.0 : 4.0,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: isMini ? 6.0 : 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
              activeTrackColor: primaryColor,
              thumbColor: primaryColor,
              inactiveTrackColor: Colors.grey[300],
            ),
            child: ValueListenableBuilder<Duration>(
              valueListenable: _audioManager.durationNotifier,
              builder: (context, totalDuration, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: _audioManager.positionNotifier,
                  builder: (context, currentPosition, _) {
                    final max = totalDuration.inMilliseconds.toDouble();
                    
                    // 🔥 ГОЛОВНА ЛОГІКА:
                    // Якщо тягнемо (_isDragging) -> беремо _dragValue (палець)
                    // Якщо слухаємо -> беремо currentPosition (плеєр)
                    final double currentValue = _isDragging 
                        ? _dragValue 
                        : currentPosition.inMilliseconds.toDouble();

                    if (max <= 0) return const Slider(value: 0, onChanged: null);

                    return Slider(
                      min: 0.0, 
                      max: max,
                      value: currentValue.clamp(0.0, max),
                      
                      // 1. Поклали палець на слайдер
                      onChangeStart: (value) {
                        setState(() {
                          _isDragging = true;
                          _dragValue = value;
                        });
                      },
                      
                      // 2. Тягнемо (змінюємо тільки візуал)
                      onChanged: (newValue) {
                        setState(() {
                          _dragValue = newValue;
                        });
                      },
                      
                      // 3. Відпустили палець (відправляємо команду плеєру)
                      onChangeEnd: (newValue) async {
                        // Важливо: ми НЕ скидаємо _isDragging = false одразу!
                        
                        // 1. Спочатку чекаємо, поки плеєр реально перемотає
                        await _audioManager.seek(Duration(milliseconds: newValue.toInt()));
                        
                        // 2. І тільки коли плеєр сказав "готово", дозволяємо слайдеру
                        // знову слухати потік позиції
                        if (mounted) {
                          setState(() {
                            _isDragging = false;
                          });
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
        
        // Загальний час справа
        ValueListenableBuilder<Duration>(
          valueListenable: _audioManager.durationNotifier,
          builder: (context, duration, _) => Text(
            _formatDuration(duration),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}