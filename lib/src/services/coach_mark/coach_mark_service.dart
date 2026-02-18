import 'package:shared_preferences/shared_preferences.dart';

class CoachMarkService {
  CoachMarkService._();
  static final instance = CoachMarkService._();

  static const String _keyHomeCoachSeen = 'coach_mark_home_seen';
  static const String _keyRecordsCoachSeen = 'coach_mark_records_seen';
  static const String _keyChatbotCoachSeen = 'coach_mark_chatbot_seen';

  Future<bool> hasSeenHomeCoachMarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHomeCoachSeen) ?? false;
  }

  Future<void> markHomeCoachMarksSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHomeCoachSeen, true);
  }

  Future<bool> hasSeenRecordsCoachMarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRecordsCoachSeen) ?? false;
  }

  Future<void> markRecordsCoachMarksSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecordsCoachSeen, true);
  }

  Future<bool> hasSeenChatbotCoachMarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyChatbotCoachSeen) ?? false;
  }

  Future<void> markChatbotCoachMarksSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyChatbotCoachSeen, true);
  }
}
