import 'package:shared_preferences/shared_preferences.dart';

class CoachMarkService {
  CoachMarkService._();
  static final instance = CoachMarkService._();

  static const String _prefix = 'coach_mark_seen_';

  // 화면별 키 상수
  static const String screenHome = 'home';
  static const String screenRecords = 'records';
  static const String screenChatbot = 'chatbot';
  static const String screenFoodRecord = 'food_record';
  static const String screenWaterRecord = 'water_record';
  static const String screenWeightRecord = 'weight_record';
  static const String screenHealthCheckMain = 'health_check_main';
  static const String screenHealthCheckHistory = 'health_check_history';
  static const String screenHealthCheckResult = 'health_check_result';
  static const String screenBhiDetail = 'bhi_detail';
  static const String screenProfile = 'profile';
  static const String screenPremium = 'premium';
  static const String screenPetProfileDetail = 'pet_profile_detail';

  /// 해당 화면의 코치마크를 이미 봤는지 확인
  Future<bool> hasSeen(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$screenKey') ?? false;
  }

  /// 해당 화면의 코치마크를 본 것으로 표시
  Future<void> markSeen(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$screenKey', true);
  }

  /// 모든 코치마크 상태 초기화 (로그아웃 시 호출)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
