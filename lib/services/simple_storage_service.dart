import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SimpleStorageService {
  static SimpleStorageService? _instance;
  SharedPreferences? _prefs;

  SimpleStorageService._internal();

  factory SimpleStorageService() {
    _instance ??= SimpleStorageService._internal();
    return _instance!;
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<UserModel?> getUser() async {
    try {
      await _init();
      final userJson = _prefs!.getString('user');

      if (userJson != null && userJson.isNotEmpty) {
        return UserModel(
          id: 1,
          name: userJson,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<bool> saveUser(String name) async {
    try {
      await _init();
      return await _prefs!.setString('user', name);
    } catch (e) {
      print('Error saving user: $e');
      return false;
    }
  }

  Future<void> clearUser() async {
    try {
      await _init();
      await _prefs!.remove('user');
    } catch (e) {
      print('Error clearing user: $e');
    }
  }
}
