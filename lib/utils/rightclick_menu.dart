import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';

class RightClickMenuWrapper extends ConsumerWidget {
  final Widget child;
  final List<PopupMenuEntry<String>> menuItems;

  const RightClickMenuWrapper({
    super.key,
    required this.child,
    required this.menuItems,
  });

  void _showContextMenu(
    BuildContext context,
    Offset position,
    WidgetRef ref,
  ) async {
    if (ref.read(popupMenuShownProvider)) return;
    if (menuItems.isEmpty) return;
    ref.read(popupMenuShownProvider.notifier).state = true;
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

    ref.read(popupMenuShownProvider.notifier).state = false;
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
