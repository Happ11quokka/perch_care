# Findings: 체중 시간대 기록 + 식이 누적 기록

## 핵심 발견사항

### 1. 체중 기록 - 현재 상태
- **모델**: `WeightRecord` - `date` 필드는 DateTime이지만 시간부분 강제 제거 (날짜만 사용)
- **서비스**: `WeightService._normalizeDate()` → `DateTime(year, month, day)` 시간 제거
- **API**: `recorded_date` 필드, YYYY-MM-DD 포맷 (시간 없음)
- **제약**: 하루 1개 기록만 가능 (Upsert 로직 - 같은 날짜 덮어쓰기)
- **차트**: fl_chart 사용, 주간/월간 뷰, 날짜 기준 그룹화

### 2. 식이 기록 - 현재 상태
- **모델**: `FoodRecord` - `recordedDate`, `totalGrams`, `targetGrams`, `count`, `entriesJson`
- **구분 없음**: 배식(serving) vs 취식(eating) 명시적 구분 없음
- **시간 없음**: entriesJson에 시간 정보 미포함
- **일 단위**: 하루 전체 집계만 가능
- **다중 음식**: entriesJson으로 여러 음식 타입 지원 (_FoodEntry)

### 3. 공통 패턴
- **시간 선택 위젯 존재**: `AnalogTimePicker` (lib/src/widgets/analog_time_picker.dart)
- **서비스 패턴**: Singleton, 하이브리드(API+SharedPreferences), Upsert
- **모델 패턴**: const constructor, fromJson/toJson/toInsertJson, copyWith
- **로컬화**: app_ko.arb/app_en.arb/app_zh.arb, `feature_keyName` 컨벤션

### 4. 주요 변경 필요 파일
**체중 시간대 기록:**
- `lib/src/models/weight_record.dart` - recordedTime 필드 추가
- `lib/src/services/weight/weight_service.dart` - 다중 기록 지원, 일평균 계산
- `lib/src/screens/weight/weight_add_screen.dart` - 시간 선택 UI 추가
- `lib/src/screens/weight/weight_detail_screen.dart` - 차트에 일평균 적용
- `lib/src/screens/weight/weight_record_screen.dart` - 다중 기록 표시

**식이 누적 기록:**
- `lib/src/models/food_record.dart` - FeedingEntry 모델 (배식/취식 구분, 시간)
- `lib/src/services/food/food_record_service.dart` - 누적 기록 API
- `lib/src/screens/food/food_record_screen.dart` - 배식/취식 UI 개편
