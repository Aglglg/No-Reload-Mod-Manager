import 'package:easy_localization/easy_localization.dart';

class ConstantVar {
  static const String thisProcessName = "No_Reload_Mod_Manager.exe";
  static const String managedBackupExtension = "ini_managed_backup";
  static const String managedFolderName = "_MANAGED_";
  static const String managedRemovedFolderName = "DISABLED_MANAGED_REMOVED";
  static const String oldManagedFolderName =
      "V1_3_x_MANAGED-DO_NOT_EDIT_COPY_MOVE_CUT";
  static const String anotherOldManagedFolderName =
      "MANAGED-DO_NOT_EDIT_COPY_MOVE_CUT";
  static const String backgroundKeypressFileName = 'background_keypress.ini';
  static const String managerGroupFileName = 'manager_group.ini';
  static String defaultErrorInfo = "defaultErrorInfo".tr();
  static const String urlSupportIcon =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/icon_support.png";
  static const String urlSupportIconOnHover =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/icon_support_onhover.png";
  static const String urlTutorialIcon =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/icon_tutorial.png";
  static const String urlTutorialIconOnHover =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/icon_tutorial_onhover.png";
  static const String urlContactIcon =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/icon_contact.png";
  static const String urlContactIconOnHover =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/icon_contact_onhover.png";
  static const String urlToGetSupportLink =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/link_support.txt";
  static const String urlToGetTutorialLink =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/link_tutorial.txt";
  static const String urlToGetContactLink =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/link_contact.txt";
  static const String urlMessageWuwa =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/message_wuwa.txt";
  static const String urlMessageGenshin =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/message_genshin.txt";
  static const String urlMessageHsr =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/message_hsr.txt";
  static const String urlMessageZzz =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/message_zzz.txt";
  static const String urlJsonAutoIcon =
      "https://raw.githubusercontent.com/Aglglg/No-Reload-Mod-Manager/refs/heads/main/assets/cloud_data/auto_icon/auto_icon.json";

  static const String urlValidKeysExample =
      "https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes";
}

enum TargetGame {
  none,
  // ignore: constant_identifier_names
  Wuthering_Waves,
  // ignore: constant_identifier_names
  Genshin_Impact,
  // ignore: constant_identifier_names
  Honkai_Star_Rail,
  // ignore: constant_identifier_names
  Zenless_Zone_Zero,
}

enum HotkeyKeyboard { altW, altS, altA, altD }

enum HotkeyGamepad { none, lsB, lsA, lsRb, selectStart }
