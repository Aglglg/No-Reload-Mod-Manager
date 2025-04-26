import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RightClickMenuWrapper extends ConsumerWidget {
  final Widget child;
  final List<PopupMenuEntry<String>> menuItems;
  final Function? onMenuClosed; // Callback for when menu is closed

  const RightClickMenuWrapper({
    super.key,
    required this.child,
    required this.menuItems,
    this.onMenuClosed, // Optional callback
  });

  void _showContextMenu(
    BuildContext context,
    Offset position,
    WidgetRef ref,
  ) async {
    await showMenu<String>(
      popUpAnimationStyle: AnimationStyle(
        duration: Duration(milliseconds: 150),
      ),
      constraints: const BoxConstraints(maxWidth: 120),
      menuPadding: EdgeInsets.all(0),
      color: const Color(0xFF535356),
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: menuItems,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (TapDownDetails details) {
        _showContextMenu(context, details.globalPosition, ref);
      },
      child: child,
    );
  }
}
