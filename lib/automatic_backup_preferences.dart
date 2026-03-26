import 'package:shared_preferences/shared_preferences.dart';

class FoodBackupPreferences {
  const FoodBackupPreferences();

  static const String _automaticBackupsEnabledKey =
      'family_eating.automatic_json_backups_enabled';

  Future<bool> loadAutomaticBackupsEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_automaticBackupsEnabledKey) ?? false;
  }

  Future<void> saveAutomaticBackupsEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_automaticBackupsEnabledKey, enabled);
  }
}
