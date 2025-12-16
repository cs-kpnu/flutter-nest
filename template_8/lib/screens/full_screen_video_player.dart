import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String chatId;
  final String startUrl;

  const FullScreenVideoPlayer({
    super.key,
    required this.chatId,
    required this.startUrl,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late PageController _pageController;
  List<Map<String, dynamic>> _videoList = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _loadVideoPlaylist();
  }

  Future<void> _loadVideoPlaylist() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('type', isEqualTo: 'video')
          .orderBy('timestamp', descending: false)
          .get();

      final videos = snapshot.docs.map((doc) => doc.data()).toList();
      int startIndex = videos.indexWhere((v) => v['url'] == widget.startUrl);
      if (startIndex == -1) startIndex = 0;

      setState(() {
        _videoList = videos;
        _currentIndex = startIndex;
        _pageController = PageController(initialPage: startIndex);
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading videos: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      // 🔥 ПОВЕРНУЛИ ПРОЗОРІСТЬ (0.85 = 85% чорного, видно чат)
      backgroundColor: Colors.black.withOpacity(0.85),
      
      body: Dismissible(
        key: const Key('video_dismiss'),
        direction: _isZoomed ? DismissDirection.none : DismissDirection.vertical, 
        onDismissed: (_) => Navigator.of(context).pop(),
        background: Container(color: Colors.transparent),
        resizeDuration: null, 
        movementDuration: const Duration(milliseconds: 100),
        dismissThresholds: const {
          DismissDirection.vertical: 0.2,
        },
        child: PageView.builder(
          physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          controller: _pageController,
          itemCount: _videoList.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final videoData = _videoList[index];
            return SingleVideoItem(
              key: ValueKey(videoData['url']), 
              url: videoData['url'],
              fileName: videoData['fileName'] ?? '',
              isVisible: index == _currentIndex,
              onZoomChanged: (isZoomed) {
                if (_isZoomed != isZoomed) {
                  Future.microtask(() {
                    if (mounted) setState(() => _isZoomed = isZoomed);
                  });
                }
              },
            );
          },
        ),
      ),
    );
  }
}

// --- ВІДЖЕТ ВІДЕО (TELEGRAM STYLE ZOOM) ---
class SingleVideoItem extends StatefulWidget {
  final String url;
  final String fileName;
  final bool isVisible;
  final Function(bool) onZoomChanged;

  const SingleVideoItem({
    super.key,
    required this.url,
    required this.fileName,
    required this.isVisible,
    required this.onZoomChanged,
  });

  @override
  State<SingleVideoItem> createState() => _SingleVideoItemState();
}

class _SingleVideoItemState extends State<SingleVideoItem> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  
  // Контролер трансформації (зум/пан)
  final TransformationController _transformationController = TransformationController();
  
  // Анімація для подвійного тапу та скидання
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  bool _isInitialized = false;
  bool _showControls = false;
  bool _isDragging = false; 
  double _sliderValue = 0.0;
  
  // Зберігає точку останнього тапу для точного зуму
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    // Налаштовуємо швидку анімацію (200мс - як в Telegram)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      _transformationController.value = _animation!.value;
    });

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) {
           _controller.dispose();
           return;
        }
        setState(() => _isInitialized = true);
        if (widget.isVisible) {
          _controller.play();
        }
      });

      _controller.setLooping(true);
      _controller.addListener(_videoListener);

      // Слухаємо зміни зуму
      _transformationController.addListener(() {
        final scale = _transformationController.value.row0.x;
        // Повідомляємо батька про зум, якщо масштаб > 1.0
        if (scale > 1.0 && !_animationController.isAnimating) {
           widget.onZoomChanged(true);
        } else {
           widget.onZoomChanged(false);
        }
      });
  }

  void _videoListener() {
    if (mounted && _isInitialized && !_isDragging && _controller.value.isPlaying) {
        setState(() {
          _sliderValue = _controller.value.position.inMilliseconds.toDouble();
        }); 
    }
  }

  @override
  void didUpdateWidget(SingleVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInitialized) return;

    if (widget.isVisible && !oldWidget.isVisible) {
      _controller.play();
    }
    
    if (!widget.isVisible && oldWidget.isVisible) {
      _controller.pause();
      setState(() => _showControls = false);
      _resetZoom();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    try {
      _controller.pause();
      _controller.dispose();
    } catch (e) {
       print(e);
    }
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- ЛОГІКА ЗУМУ (TELEGRAM MATH) ---

  // Скидання зуму в 1.0 (повернення до нормального стану)
  void _resetZoom() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward(from: 0);
    widget.onZoomChanged(false);
  }

  // Обробка подвійного тапу
  void _handleDoubleTap() {
    Matrix4 endMatrix;
    
    if (_transformationController.value.isIdentity()) {
      // 1. Якщо масштаб нормальний -> Збільшуємо в 3 рази в точку натискання
      
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      
      // Математика зуму в точку:
      // Зсуваємо світ так, щоб точка натискання стала центром (0,0),
      // масштабуємо, потім зсуваємо назад.
      // Але для InteractiveViewer простіше так:
      // Translate to negative touch point * (scale - 1)
      
      const double scale = 3.0;
      final x = -position.dx * (scale - 1);
      final y = -position.dy * (scale - 1);

      endMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale);
        
    } else {
      // 2. Якщо вже збільшено -> Повертаємо назад
      endMatrix = Matrix4.identity();
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    
    _animationController.forward(from: 0);
  }

  // --- UI МЕТОДИ ---
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && _controller.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying && !_isDragging) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _playPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
      } else {
        _controller.play();
        _toggleControls(); 
      }
    });
  }

  void _onSliderChangeStart(double value) {
    setState(() => _isDragging = true);
    _controller.pause(); 
  }

  void _onSliderChanged(double value) {
    setState(() => _sliderValue = value);
  }

  void _onSliderChangeEnd(double value) async {
    await _controller.seekTo(Duration(milliseconds: value.toInt()));
    setState(() => _isDragging = false);
    _controller.play(); 
    _toggleControls();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final duration = _controller.value.duration;
    final maxDuration = duration.inMilliseconds.toDouble();
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. ІНТЕРАКТИВНЕ ВІДЕО (ОСНОВНИЙ ШАР)
        Positioned.fill(
          child: GestureDetector(
            // Ловимо координати тапу для зуму
            onDoubleTapDown: (d) => _doubleTapDetails = d,
            onDoubleTap: _handleDoubleTap,
            onTap: _toggleControls,
            child: InteractiveViewer(
              transformationController: _transformationController,
              // minScale < 1.0 дає "гумовий ефект"
              minScale: 0.8, 
              maxScale: 5.0,
              panEnabled: true, 
              
              // Коли відпускаємо пальці
              onInteractionEnd: (details) {
                double scale = _transformationController.value.row0.x;
                // Якщо зменшили менше норми -> повертаємо назад (гумка)
                if (scale < 1.0) {
                  _resetZoom();
                }
              },
              
              // Прозорий контейнер на весь екран
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
        ),
        
        // 2. ФОН КОНТРОЛІВ (Пропускає жести)
        if (_showControls || !_controller.value.isPlaying)
          IgnorePointer(
            ignoring: true, 
            child: Container(color: Colors.black38),
          ),

        // 3. PLAY/PAUSE КНОПКА
        if (_showControls || !_controller.value.isPlaying)
           GestureDetector(
             onTap: _playPause,
             child: Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 70,
              ),
             ),
           ),

        // 4. ПАНЕЛЬ УПРАВЛІННЯ
        if (_showControls || !_controller.value.isPlaying)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent]
                )
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.fileName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(_formatDuration(Duration(milliseconds: _sliderValue.toInt())), style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.red,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.red,
                            overlayColor: Colors.red.withOpacity(0.2),
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                          ),
                          child: Slider(
                            min: 0.0,
                            max: maxDuration > 0 ? maxDuration : 1.0,
                            value: _sliderValue.clamp(0.0, maxDuration > 0 ? maxDuration : 1.0),
                            onChangeStart: _onSliderChangeStart,
                            onChanged: _onSliderChanged,
                            onChangeEnd: _onSliderChangeEnd,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(_formatDuration(duration), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
        if (_controller.value.isBuffering)
           const IgnorePointer(child: Center(child: CircularProgressIndicator(color: Colors.white))),
      ],
    );
  }
}