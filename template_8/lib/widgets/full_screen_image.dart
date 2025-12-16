import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FullScreenImageGallery extends StatefulWidget {
  final String chatId;
  final String startUrl;

  const FullScreenImageGallery({
    super.key,
    required this.chatId,
    required this.startUrl,
  });

  @override
  State<FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<FullScreenImageGallery> {
  late PageController _pageController;
  List<Map<String, dynamic>> _imageList = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  
  // Блокуємо свайп між фото, коли зумимо
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _loadImagePlaylist();
  }

  Future<void> _loadImagePlaylist() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('type', isEqualTo: 'image')
          .orderBy('timestamp', descending: false)
          .get();

      final images = snapshot.docs.map((doc) {
        final data = doc.data();
        data['messageId'] = doc.id; 
        return data;
      }).toList();
      
      int startIndex = images.indexWhere((img) => img['url'] == widget.startUrl);
      if (startIndex == -1) startIndex = 0;

      setState(() {
        _imageList = images;
        _currentIndex = startIndex;
        _pageController = PageController(initialPage: startIndex);
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading images: $e");
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
      // 🔥 ПРОЗОРІСТЬ (85% чорного)
      backgroundColor: Colors.black.withOpacity(0.85),
      extendBodyBehindAppBar: true,
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _imageList.length > 1 
          ? Text("${_currentIndex + 1} з ${_imageList.length}", style: const TextStyle(color: Colors.white))
          : null,
        centerTitle: true,
      ),
      
      body: Dismissible(
        key: const Key('image_gallery_dismiss'),
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
          itemCount: _imageList.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final imageData = _imageList[index];
            final url = imageData['url'];
            final uniqueHeroTag = imageData['messageId'] ?? url;

            return SingleImageItem(
              imageUrl: url,
              heroTag: uniqueHeroTag,
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

// --- ОКРЕМИЙ ВІДЖЕТ ДЛЯ ФОТО (TELEGRAM ZOOM) ---
class SingleImageItem extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final Function(bool) onZoomChanged;

  const SingleImageItem({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.onZoomChanged,
  });

  @override
  State<SingleImageItem> createState() => _SingleImageItemState();
}

class _SingleImageItemState extends State<SingleImageItem> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      _transformationController.value = _animation!.value;
    });

    _transformationController.addListener(() {
      final scale = _transformationController.value.row0.x;
      // Якщо масштаб більше 1.0, блокуємо гортання
      if (scale > 1.0 && !_animationController.isAnimating) {
        widget.onZoomChanged(true);
      } else {
        widget.onZoomChanged(false);
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward(from: 0);
    widget.onZoomChanged(false);
  }

  void _handleDoubleTap() {
    Matrix4 endMatrix;
    
    if (_transformationController.value.isIdentity()) {
      // Зум в 3 рази в точку натискання
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const double scale = 3.0;
      final x = -position.dx * (scale - 1);
      final y = -position.dy * (scale - 1);

      endMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale);
    } else {
      endMatrix = Matrix4.identity();
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true,
        // Гумовий ефект при зменшенні
        minScale: 0.8,
        maxScale: 5.0,
        
        onInteractionEnd: (details) {
          double scale = _transformationController.value.row0.x;
          if (scale < 1.0) {
            _resetZoom();
          }
        },
        
        // Прозорий контейнер на весь екран
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Hero(
            tag: widget.heroTag,
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              },
              errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.broken_image, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}