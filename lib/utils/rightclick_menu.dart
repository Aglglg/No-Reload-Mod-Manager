import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/utils/check_admin_privillege.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';

class RightClickMenuWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final List<PopupMenuEntry<String>> menuItems;

  const RightClickMenuWrapper({
    super.key,
    required this.child,
    required this.menuItems,
  });

  @override
  ConsumerState<RightClickMenuWrapper> createState() =>
      _RightClickMenuWrapperState();
}

class _RightClickMenuWrapperState extends ConsumerState<RightClickMenuWrapper> {
  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    // ✅ Use container instead of ref, for safety
    final container = ProviderScope.containerOf(context, listen: false);

    if (container.read(popupMenuShownProvider)) return;
    if (widget.menuItems.isEmpty) return;

    container.read(popupMenuShownProvider.notifier).state = true;

    await showMenu<String>(
      popUpAnimationStyle: AnimationStyle(
        duration: Duration(milliseconds: 150),
      ),
      constraints: const BoxConstraints(maxWidth: 120),
      menuPadding: EdgeInsets.zero,
      color: const Color(0xFF2B2930),
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: widget.menuItems,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );

    // ✅ Will still work even if widget is gone
    container.read(popupMenuShownProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (TapDownDetails details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: widget.child,
    );
  }
}
