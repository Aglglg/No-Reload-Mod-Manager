import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';

class RefreshableLocalImage extends ConsumerStatefulWidget {
  final Image? imageWidget;
  final Widget errorWidget;

  const RefreshableLocalImage({
    required this.imageWidget,
    required this.errorWidget,
    super.key,
  });

  @override
  ConsumerState<RefreshableLocalImage> createState() =>
      _RefreshableLocalImageState();
}

class _RefreshableLocalImageState extends ConsumerState<RefreshableLocalImage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageWidget != null) {
      return widget.imageWidget!;
    } else {
      return widget.errorWidget;
    }
  }
}

class ImageRefreshListener {
  static void refreshImages(List<ModGroupData> modGroupDatas) {
    for (final groupData in modGroupDatas) {
      if (groupData.groupIcon != null) {
        groupData.groupIcon!.image.evict();
      }
      for (var modData in groupData.modsInGroup) {
        if (modData.modIcon != null) {
          modData.modIcon!.image.evict();
        }
      }
    }
  }
}
