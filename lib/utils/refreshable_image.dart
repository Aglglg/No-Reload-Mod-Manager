import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RefreshableLocalImage extends ConsumerStatefulWidget {
  final String path;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )
  errorBuilder;

  const RefreshableLocalImage({
    required this.path,
    required this.errorBuilder,
    super.key,
  });

  @override
  ConsumerState<RefreshableLocalImage> createState() =>
      _RefreshableLocalImageState();
}

class _RefreshableLocalImageState extends ConsumerState<RefreshableLocalImage>
    with ImageRefreshListener {
  late FileImage fileImage;

  @override
  void initState() {
    super.initState();
    fileImage = FileImage(File(widget.path));
    ImageRefreshListener.addListener(this);
  }

  @override
  void dispose() {
    ImageRefreshListener.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: fileImage,
      fit: BoxFit.cover,
      errorBuilder: widget.errorBuilder,
    );
  }

  @override
  void onRefresh() {
    print("REFRESH");
    fileImage.evict();
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
