import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen photo viewer: pinch / scroll-wheel zoom, double-tap to zoom,
/// swipe or arrow buttons / keys to change photo. Pops with the last viewed index.
class FullImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const FullImageViewer({super.key, required this.urls, this.initialIndex = 0});

  static Future<int?> open(BuildContext context, List<String> urls, int index) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullImageViewer(urls: urls, initialIndex: index),
      ),
    );
  }

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late final PageController _ctrl;
  late int _index;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= widget.urls.length) return;
    _ctrl.animateToPage(i,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _close() => Navigator.of(context).pop(_index);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(_index - 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(_index + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback? onTap, Alignment align) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
          color: Colors.white,
          disabledColor: Colors.white24,
          icon: Icon(icon, size: 30),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.urls.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: count,
                  // While zoomed in, dragging pans the photo instead of changing it.
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (i) => setState(() {
                    _index = i;
                    _zoomed = false;
                  }),
                  itemBuilder: (_, i) => _ZoomablePhoto(
                    key: ValueKey(widget.urls[i]),
                    url: widget.urls[i],
                    onZoomChanged: (z) {
                      if (i == _index && z != _zoomed) setState(() => _zoomed = z);
                    },
                  ),
                ),
              ),
              if (count > 1) ...[
                _arrow(Icons.chevron_left, 'Foto sebelumnya',
                    _index > 0 ? () => _go(_index - 1) : null, Alignment.centerLeft),
                _arrow(Icons.chevron_right, 'Foto selanjutnya',
                    _index < count - 1 ? () => _go(_index + 1) : null,
                    Alignment.centerRight),
              ],
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Tutup',
                        onPressed: _close,
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        color: Colors.white,
                        icon: const Icon(Icons.close),
                      ),
                      const Spacer(),
                      if (count > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('${_index + 1}/$count',
                              style: const TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomablePhoto({super.key, required this.url, required this.onZoomChanged});

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _tc = TransformationController();
  Offset _tapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => widget.onZoomChanged(_tc.value.getMaxScaleOnAxis() > 1.01));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_tc.value.getMaxScaleOnAxis() > 1.01) {
      _tc.value = Matrix4.identity();
    } else {
      const s = 2.5;
      _tc.value = Matrix4.identity()
        ..translate(-_tapPos.dx * (s - 1), -_tapPos.dy * (s - 1))
        ..scale(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tapPos = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}
