import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:no_reload_mod_manager/casual_style/dds_handler_bridge.dart';

class DdsImage extends StatefulWidget {
  final String path;
  final double width, height;
  const DdsImage({
    required this.path,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  State<DdsImage> createState() => _DdsImageState();
}

class _DdsImageState extends State<DdsImage> {
  ui.Image? _image;

  void _loadImage() {
    decodeDdsToImage(widget.path).then((img) {
      if (mounted && img != null) {
        setState(() => _image = img);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(DdsImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _image?.dispose();
      _image = null;
      _loadImage();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return Icon(
        Icons.image_rounded,
        size: widget.width,
        color: const Color.fromARGB(255, 169, 169, 169),
      );
    }
    return RawImage(
      image: _image,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
    );
  }
}
