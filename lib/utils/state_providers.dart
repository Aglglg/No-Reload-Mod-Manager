import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_reload_mod_manager/data/mod_data.dart';
import 'package:no_reload_mod_manager/utils/constant_var.dart';
import 'package:no_reload_mod_manager/utils/shared_pref.dart';

final StateProvider<TargetGame> targetGameProvider = StateProvider<TargetGame>(
  (ref) => TargetGame.none,
);

final StateProvider<bool> windowIsPinnedProvider = StateProvider<bool>(
  (ref) => false,
);

final StateProvider<int> tabIndexProvider = StateProvider<int>((ref) => 1);

final StateProvider<bool> alertDialogShownProvider = StateProvider<bool>(
  (ref) => false,
);

final StateProvider<bool> popupMenuShownProvider = StateProvider<bool>(
  (ref) => false,
);

final StateProvider<String> supportLinkProvider = StateProvider<String>(
  (ref) => "",
);
final StateProvider<String> tutorialLinkProvider = StateProvider<String>(
  (ref) => "",
);

final StateProvider<bool> messageWuwaDismissedProvider = StateProvider<bool>(
  (ref) => false,
);
final StateProvider<bool> messageGenshinDismissedProvider = StateProvider<bool>(
  (ref) => false,
);
final StateProvider<bool> messageHsrDismissedProvider = StateProvider<bool>(
  (ref) => false,
);
final StateProvider<bool> messageZzzDismissedProvider = StateProvider<bool>(
  (ref) => false,
);

final StateProvider<HotkeyKeyboard> hotkeyKeyboardProvider =
    StateProvider<HotkeyKeyboard>((ref) {
      SharedPrefUtils().init();
      return SharedPrefUtils().getHotkeyKeyboard();
    });
final StateProvider<HotkeyGamepad> hotkeyGamepadProvider =
    StateProvider<HotkeyGamepad>((ref) {
      SharedPrefUtils().init();
      return SharedPrefUtils().getHotkeyGamepad();
    });

final StateProvider<List<ModGroupData>> modGroupDataProvider =
    StateProvider<List<ModGroupData>>((ref) {
      return [];
    });

final currentGroupIndexProvider = StateProvider<int>((ref) => 0);

final focusedOnTextField = StateProvider<bool>((ref) => false);

final modsPathIsValid = StateProvider<bool>((ref) => false);
