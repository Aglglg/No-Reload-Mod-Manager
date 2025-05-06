import 'package:flutter/services.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulate.dart';
import 'package:win32/win32.dart';

void simulateKeyF10() {
  _simulateKeypress([VK_F10]);
}

Future<void> simulateKeySelectMod(int realGroupIndex, int modIndex) async {
  List<int> keysGroupToBeSimulated = [];
  List<int> keysModToBeSimulated = [];
  _keymapGroupIndex(keysGroupToBeSimulated, realGroupIndex);
  _keymapModIndex(keysModToBeSimulated, modIndex);

  //Execute
  simulateKeyDown(VK_CLEAR);
  await _simulateKeypress(keysGroupToBeSimulated);
  await _simulateKeypress(keysModToBeSimulated);
  simulateKeyUp(VK_CLEAR);
}

void somethingA(List<PhysicalKeyboardKey> keys) {
  keys.add(PhysicalKeyboardKey.slash);
}

void somethingB(List<PhysicalKeyboardKey> keys) {
  keys.add(PhysicalKeyboardKey.keyN);
}

Future<void> _simulateKeypress(List<int> keys) async {
  for (var key in keys) {
    simulateKeyDown(key);
  }

  await Future.delayed(Duration(milliseconds: 50));

  for (var key in keys) {
    simulateKeyUp(key);
  }
}

void _keymapGroupIndex(List<int> virtualKeys, int index) {
  switch (index) {
    case 1:
      virtualKeys.add(VK_F13); // NO_RETURN NO_BACK
      break;
    case 2:
      virtualKeys.add(VK_F14);
      break;
    case 3:
      virtualKeys.add(VK_F15);
      break;
    case 4:
      virtualKeys.add(VK_F16);
      break;
    case 5:
      virtualKeys.add(VK_F17);
      break;
    case 6:
      virtualKeys.add(VK_F18);
      break;
    case 7:
      virtualKeys.add(VK_F19);
      break;
    case 8:
      virtualKeys.add(VK_F20);
      break;
    case 9:
      virtualKeys.add(VK_F21);
      break;
    case 10:
      virtualKeys.add(VK_F22);
      break;
    case 11:
      virtualKeys.add(VK_F23);
      break;
    case 12:
      virtualKeys.add(VK_F24);
      break;
    case 13:
      virtualKeys.add(VK_RETURN); //NO_BACK
      virtualKeys.add(VK_F13);
      break;
    case 14:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F14);
      break;
    case 15:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F15);
      break;
    case 16:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F16);
      break;
    case 17:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F17);
      break;
    case 18:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F18);
      break;
    case 19:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F19);
      break;
    case 20:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F20);
      break;
    case 21:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F21);
      break;
    case 22:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F22);
      break;
    case 23:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F23);
      break;
    case 24:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_F24);
      break;
    case 25:
      virtualKeys.add(VK_BACK); //NO RETURN
      virtualKeys.add(VK_F13);
      break;
    case 26:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F14);
      break;
    case 27:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F15);
      break;
    case 28:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F16);
      break;
    case 29:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F17);
      break;
    case 30:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F18);
      break;
    case 31:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F19);
      break;
    case 32:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F20);
      break;
    case 33:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F21);
      break;
    case 34:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F22);
      break;
    case 35:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F23);
      break;
    case 36:
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F24);
      break;
    case 37:
      virtualKeys.add(VK_RETURN); //no NO_
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F13);
      break;
    case 38:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F14);
      break;
    case 39:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F15);
      break;
    case 40:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F16);
      break;
    case 41:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F17);
      break;
    case 42:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F18);
      break;
    case 43:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F19);
      break;
    case 44:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F20);
      break;
    case 45:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F21);
      break;
    case 46:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F22);
      break;
    case 47:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F23);
      break;
    case 48:
      virtualKeys.add(VK_RETURN);
      virtualKeys.add(VK_BACK);
      virtualKeys.add(VK_F24);
      break;
    default:
      break;
  }
}

void _keymapModIndex(List<int> virtualKeys, int index) {
  switch (index) {
    case 0:
      virtualKeys.add(VK_ESCAPE);
      break;
    case 1:
      virtualKeys.add(VK_1); //NO_RCONTROL NO_TAB
      break;
    case 2:
      virtualKeys.add(VK_2);
      break;
    case 3:
      virtualKeys.add(VK_3);
      break;
    case 4:
      virtualKeys.add(VK_4);
      break;
    case 5:
      virtualKeys.add(VK_5);
      break;
    case 6:
      virtualKeys.add(VK_RCONTROL); //NO_TAB
      virtualKeys.add(VK_1);
      break;
    case 7:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_2);
      break;
    case 8:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_3);
      break;
    case 9:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_4);
      break;
    case 10:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_5);
      break;
    case 11:
      virtualKeys.add(VK_TAB); //NO_RCONTROL
      virtualKeys.add(VK_1);
      break;
    case 12:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_2);
      break;
    case 13:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_3);
      break;
    case 14:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_4);
      break;
    case 15:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_5);
      break;
    case 16:
      virtualKeys.add(VK_RCONTROL); //no NO_
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_1);
      break;
    case 17:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_2);
      break;
    case 18:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_3);
      break;
    case 19:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_4);
      break;
    case 20:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_5);
      break;
    case 21:
      virtualKeys.add(VK_Z); //NO_RCONTROL NO_TAB
      break;
    case 22:
      virtualKeys.add(VK_X);
      break;
    case 23:
      virtualKeys.add(VK_C);
      break;
    case 24:
      virtualKeys.add(VK_V);
      break;
    case 25:
      virtualKeys.add(VK_B);
      break;
    case 26:
      virtualKeys.add(VK_RCONTROL); //NO_TAB
      virtualKeys.add(VK_Z);
      break;
    case 27:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_X);
      break;
    case 28:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_C);
      break;
    case 29:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_V);
      break;
    case 30:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_B);
      break;
    case 31:
      virtualKeys.add(VK_TAB); //NO_RCONTROL
      virtualKeys.add(VK_Z);
      break;
    case 32:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_X);
      break;
    case 33:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_C);
      break;
    case 34:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_V);
      break;
    case 35:
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_B);
      break;
    case 36:
      virtualKeys.add(VK_RCONTROL); //no NO_
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_Z);
      break;
    case 37:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_X);
      break;
    case 38:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_C);
      break;
    case 39:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_V);
      break;
    case 40:
      virtualKeys.add(VK_RCONTROL);
      virtualKeys.add(VK_TAB);
      virtualKeys.add(VK_B);
      break;
    default:
      virtualKeys.add(VK_ESCAPE);
      break;
  }
}
