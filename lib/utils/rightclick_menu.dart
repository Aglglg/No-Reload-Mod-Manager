import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/utils/state_providers.dart';

class RightClickMenuRegion extends ConsumerStatefulWidget {
  final Widget child;
  final List<ContextMenuEntry<dynamic>> menuItems;

  const RightClickMenuRegion({
    super.key,
    required this.child,
    required this.menuItems,
  });

  @override
  ConsumerState<RightClickMenuRegion> createState() =>
      _RightClickMenuRegionState();
}

class _RightClickMenuRegionState extends ConsumerState<RightClickMenuRegion> {
  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final sss = ref.read(zoomScaleProvider);

    final container = ProviderScope.containerOf(context, listen: false);

    if (container.read(popupMenuShownProvider)) return;
    if (widget.menuItems.isEmpty) return;

    container.read(popupMenuShownProvider.notifier).state = true;

    final contextMenu = ContextMenu(
      entries: widget.menuItems,
      padding: EdgeInsets.all(0),
      boxDecoration: BoxDecoration(
        color: const Color(0xFF2B2930),
        borderRadius: BorderRadius.circular(15 * sss),
      ),
      position: position,
    );

    await contextMenu.show(context);

    // Will still work even if widget is gone
    container.read(popupMenuShownProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (TapUpDetails details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: widget.child,
    );
  }
}
