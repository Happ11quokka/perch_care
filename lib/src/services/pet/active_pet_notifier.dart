import 'package:flutter/foundation.dart';

/// 활성 펫 변경을 앱 전체에 브로드캐스트하는 싱글톤 notifier.
/// PetProfileScreen 등에서 펫을 선택하면 notify()를 호출하고,
/// HomeScreen 등에서 addListener로 변경을 감지하여 데이터를 리로드한다.
class ActivePetNotifier extends ChangeNotifier {
  ActivePetNotifier._();
  static final instance = ActivePetNotifier._();

  String? _activePetId;
  String? get activePetId => _activePetId;

  /// 활성 펫이 변경되었음을 알린다. (동일 petId 중복 알림 방지)
  void notify(String petId) {
    if (_activePetId == petId) return;
    _activePetId = petId;
    notifyListeners();
  }
}
