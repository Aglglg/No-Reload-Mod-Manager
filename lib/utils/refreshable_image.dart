import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RefreshableLocalImage extends ConsumerStatefulWidget {
  final ImageProvider? fileImage;
  final Widget errorWidget;

  const RefreshableLocalImage({
    required this.fileImage,
    required this.errorWidget,
    super.key,
  });

  @override
  ConsumerState<RefreshableLocalImage> createState() =>
      _RefreshableLocalImageState();
}

class _RefreshableLocalImageState extends ConsumerState<RefreshableLocalImage>
    with ImageRefreshListener {
  @override
  void initState() {
    super.initState();
    ImageRefreshListener.addListener(this);
  }

  @override
  void dispose() {
    ImageRefreshListener.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fileImage != null) {
      return Image(
        image: widget.fileImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => widget.errorWidget,
      );
    } else {
      return widget.errorWidget;
    }
  }

  @override
  void onRefresh() {
    widget.fileImage?.evict();
  }
}

abstract mixin class ImageRefreshListener {
  void onRefresh();
  // Keep track of all listeners
  static final List<ImageRefreshListener> _listeners = [];

  // Add a listener
  static void addListener(ImageRefreshListener listener) {
    _listeners.add(listener);
  }

  // Remove a listener
  static void removeListener(ImageRefreshListener listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners
  static void notifyListeners() {
    for (final listener in _listeners) {
      listener.onRefresh();
    }
  }
}
