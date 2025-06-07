import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:google_fonts/google_fonts.dart';

final class CustomMenuItem<T> extends ContextMenuItem<T> {
  final String label;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final double scale;
  final Color? textColor;

  const CustomMenuItem({
    required this.label,
    this.leftIcon,
    this.rightIcon,
    super.value,
    super.onSelected,
    super.enabled,
    required this.scale,
    this.textColor,
  });

  const CustomMenuItem.submenu({
    required this.label,
    required List<ContextMenuEntry> items,
    this.leftIcon,
    this.rightIcon,
    super.onSelected,
    super.enabled,
    required this.scale,
    this.textColor,
  }) : super.submenu(items: items);

  @override
  Widget builder(
    BuildContext context,
    ContextMenuState menuState, [
    FocusNode? focusNode,
  ]) {
    bool isFocused = menuState.focusedEntry == this;

    final textStyle = GoogleFonts.poppins(
      color: textColor ?? Colors.white,
      fontWeight: FontWeight.w500,
      fontSize: 12 * scale,
    );

    // ~~~~~~~~~~ //

    return ConstrainedBox(
      constraints: BoxConstraints.expand(height: 37 * scale),
      child: Material(
        color:
            !enabled
                ? Colors.transparent
                : isFocused
                ? const Color.fromARGB(15, 255, 255, 255)
                : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: !enabled ? null : () => handleItemSelection(context),
          canRequestFocus: false,
          child: DefaultTextStyle(
            style: textStyle,
            child: Row(
              children: [
                if (leftIcon != null)
                  SizedBox.square(
                    dimension: 32.0 * scale,
                    child: Icon(
                      leftIcon,
                      size: 16.0 * scale,
                      color: Colors.white,
                    ),
                  ),
                SizedBox(width: (leftIcon == null ? 15.0 : 4.0) * scale),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width:
                      ((isSubmenuItem || rightIcon != null) ? 8.0 : 17.0) *
                      scale,
                ),
                if (isSubmenuItem || rightIcon != null)
                  SizedBox.square(
                    dimension: 32.0 * scale,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Icon(
                        isSubmenuItem ? Icons.arrow_right : rightIcon,
                        size: 16.0 * scale,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  String get debugLabel => "[${hashCode.toString().substring(0, 5)}] $label";
}
