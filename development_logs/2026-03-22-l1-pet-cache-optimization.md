# L-1: PetLocalCacheService 인메모리 캐시 최적화

> 구현일: 2026-03-22

## 문제

`PetLocalCacheService`의 모든 메서드가 매번 SharedPreferences에서 전체 펫 리스트를 JSON으로 읽고 → 역직렬화 → 수정 → 직렬화 → 다시 저장하는 O(n) 패턴.

```
getPets()    → SharedPreferences.getString → jsonDecode → List<PetProfileCache>
upsertPet()  → getPets() + 수정 + _savePets()  (전체 읽고 전체 쓰기)
removePet()  → getPets() + 수정 + _savePets()  (전체 읽고 전체 쓰기)
getActivePet() → getPets() + SharedPreferences.getString  (매번 2회 접근)
```

## 해결

인메모리 캐시 2개 추가:

```dart
List<PetProfileCache>? _cachedPets;       // 펫 리스트 캐시
String? _cachedActivePetId;               // 활성 펫 ID 캐시
bool _activePetIdLoaded = false;          // 활성 펫 ID 로드 여부
```

### 변경 후 동작

| 메서드 | 변경 전 | 변경 후 |
|--------|---------|---------|
| `getPets()` | 매번 SharedPreferences 읽기 | 캐시 있으면 즉시 반환 |
| `getActivePet()` | 매번 SharedPreferences 2회 | 캐시된 리스트 + ID로 즉시 조회 |
| `upsertPet()` | 전체 읽기 → 수정 → 전체 쓰기 | 인메모리 수정 → 백그라운드 저장 |
| `removePet()` | 전체 읽기 → 수정 → 전체 쓰기 | 인메모리 수정 → 백그라운드 저장 |
| `clearAll()` | SharedPreferences만 삭제 | 인메모리 + SharedPreferences 모두 초기화 |

### Public API 변경 없음

모든 메서드 시그니처 동일. 9개 호출부 수정 불필요.

## 테스트 이슈

싱글톤 인메모리 캐시가 테스트 간에 유지되어 테스트 격리 문제 발생.

해결: `setUpPrefs`에서 `clearAll()` → `setMockInitialValues` 순서로 호출하여 인메모리 캐시 리셋 + SharedPreferences mock 재설정.

```dart
Future<void> setUpPrefs({...}) async {
  SharedPreferences.setMockInitialValues(map);
  await PetLocalCacheService.instance.clearAll();  // 인메모리 캐시 리셋
  SharedPreferences.setMockInitialValues(map);     // mock 데이터 재설정
}
```

## 검증

```
flutter test test/features/feature4_pet_delete/  — 8/8 passed
flutter test                                      — 169/169 passed
flutter analyze                                   — 0 errors
```
