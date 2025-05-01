import 'package:flutter/services.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:no_reload_mod_manager/utils/keypress_simulate.dart';
import 'package:win32/win32.dart';

void simulateKeyF10() {
  _simulateKeypress([PhysicalKeyboardKey.f10]);
}

Future<void> simulateKeySelectMod(int groupIndex, int modIndex) async {
  List<PhysicalKeyboardKey> keysGroupToBeSimulated = [];
  List<PhysicalKeyboardKey> keysModToBeSimulated = [];
  _keymapGroupIndex(
    keysGroupToBeSimulated,
    groupIndex + 1,
  ); //+1 because group starts with group_1 whereas usual list index always starts with 0
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

Future<void> _simulateKeypress(List<PhysicalKeyboardKey> keys) async {
  for (var key in keys) {
    await keyPressSimulator.simulateKeyDown(key);
  }

  await Future.delayed(Duration(milliseconds: 50));

  for (var key in keys) {
    await keyPressSimulator.simulateKeyUp(key);
  }
}

void _keymapGroupIndex(List<PhysicalKeyboardKey> keys, int index) {
  switch (index) {
    case 1:
      keys.add(PhysicalKeyboardKey.f13); // NO_RETURN NO_BACK
      break;
    case 2:
      keys.add(PhysicalKeyboardKey.f14);
      break;
    case 3:
      keys.add(PhysicalKeyboardKey.f15);
      break;
    case 4:
      keys.add(PhysicalKeyboardKey.f16);
      break;
    case 5:
      keys.add(PhysicalKeyboardKey.f17);
      break;
    case 6:
      keys.add(PhysicalKeyboardKey.f18);
      break;
    case 7:
      keys.add(PhysicalKeyboardKey.f19);
      break;
    case 8:
      keys.add(PhysicalKeyboardKey.f20);
      break;
    case 9:
      keys.add(PhysicalKeyboardKey.f21);
      break;
    case 10:
      keys.add(PhysicalKeyboardKey.f22);
      break;
    case 11:
      keys.add(PhysicalKeyboardKey.f23);
      break;
    case 12:
      keys.add(PhysicalKeyboardKey.f24);
      break;
    case 13:
      keys.add(PhysicalKeyboardKey.enter); //NO_BACK
      keys.add(PhysicalKeyboardKey.f13);
      break;
    case 14:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f14);
      break;
    case 15:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f15);
      break;
    case 16:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f16);
      break;
    case 17:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f17);
      break;
    case 18:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f18);
      break;
    case 19:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f19);
      break;
    case 20:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f20);
      break;
    case 21:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f21);
      break;
    case 22:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f22);
      break;
    case 23:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f23);
      break;
    case 24:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.f24);
      break;
    case 25:
      keys.add(PhysicalKeyboardKey.backspace); //NO RETURN
      keys.add(PhysicalKeyboardKey.f13);
      break;
    case 26:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f14);
      break;
    case 27:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f15);
      break;
    case 28:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f16);
      break;
    case 29:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f17);
      break;
    case 30:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f18);
      break;
    case 31:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f19);
      break;
    case 32:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f20);
      break;
    case 33:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f21);
      break;
    case 34:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f22);
      break;
    case 35:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f23);
      break;
    case 36:
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f24);
      break;
    case 37:
      keys.add(PhysicalKeyboardKey.enter); //no NO_
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f13);
      break;
    case 38:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f14);
      break;
    case 39:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f15);
      break;
    case 40:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f16);
      break;
    case 41:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f17);
      break;
    case 42:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f18);
      break;
    case 43:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f19);
      break;
    case 44:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f20);
      break;
    case 45:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f21);
      break;
    case 46:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f22);
      break;
    case 47:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f23);
      break;
    case 48:
      keys.add(PhysicalKeyboardKey.enter);
      keys.add(PhysicalKeyboardKey.backspace);
      keys.add(PhysicalKeyboardKey.f24);
      break;
    default:
      break;
  }
}

void _keymapModIndex(List<PhysicalKeyboardKey> keys, int index) {
  switch (index) {
    case 0:
      keys.add(PhysicalKeyboardKey.escape);
      break;
    case 1:
      keys.add(PhysicalKeyboardKey.digit1); //NO_RCONTROL NO_TAB
      break;
    case 2:
      keys.add(PhysicalKeyboardKey.digit2);
      break;
    case 3:
      keys.add(PhysicalKeyboardKey.digit3);
      break;
    case 4:
      keys.add(PhysicalKeyboardKey.digit4);
      break;
    case 5:
      keys.add(PhysicalKeyboardKey.digit5);
      break;
    case 6:
      keys.add(PhysicalKeyboardKey.controlRight); //NO_TAB
      keys.add(PhysicalKeyboardKey.digit1);
      break;
    case 7:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.digit2);
      break;
    case 8:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.digit3);
      break;
    case 9:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.digit4);
      break;
    case 10:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.digit5);
      break;
    case 11:
      keys.add(PhysicalKeyboardKey.tab); //NO_RCONTROL
      keys.add(PhysicalKeyboardKey.digit1);
      break;
    case 12:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit2);
      break;
    case 13:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit3);
      break;
    case 14:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit4);
      break;
    case 15:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit5);
      break;
    case 16:
      keys.add(PhysicalKeyboardKey.controlRight); //no NO_
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit1);
      break;
    case 17:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit2);
      break;
    case 18:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit3);
      break;
    case 19:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit4);
      break;
    case 20:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.digit5);
      break;
    case 21:
      keys.add(PhysicalKeyboardKey.keyZ); //NO_RCONTROL NO_TAB
      break;
    case 22:
      keys.add(PhysicalKeyboardKey.keyX);
      break;
    case 23:
      keys.add(PhysicalKeyboardKey.keyC);
      break;
    case 24:
      keys.add(PhysicalKeyboardKey.keyV);
      break;
    case 25:
      keys.add(PhysicalKeyboardKey.keyB);
      break;
    case 26:
      keys.add(PhysicalKeyboardKey.controlRight); //NO_TAB
      keys.add(PhysicalKeyboardKey.keyZ);
      break;
    case 27:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.keyX);
      break;
    case 28:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.keyC);
      break;
    case 29:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.keyV);
      break;
    case 30:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.keyB);
      break;
    case 31:
      keys.add(PhysicalKeyboardKey.tab); //NO_RCONTROL
      keys.add(PhysicalKeyboardKey.keyZ);
      break;
    case 32:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyX);
      break;
    case 33:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyC);
      break;
    case 34:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyV);
      break;
    case 35:
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyB);
      break;
    case 36:
      keys.add(PhysicalKeyboardKey.controlRight); //no NO_
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyZ);
      break;
    case 37:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyX);
      break;
    case 38:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyC);
      break;
    case 39:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyV);
      break;
    case 40:
      keys.add(PhysicalKeyboardKey.controlRight);
      keys.add(PhysicalKeyboardKey.tab);
      keys.add(PhysicalKeyboardKey.keyB);
      break;
    default:
      keys.add(PhysicalKeyboardKey.escape);
      break;
  }
}
