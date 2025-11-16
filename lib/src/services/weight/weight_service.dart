import '../../models/weight_record.dart';

/// 체중 데이터 관리 서비스
/// 현재는 인메모리 리스트로 관리, 추후 Supabase 연동 예정
class WeightService {
  WeightService._();

  static final WeightService _instance = WeightService._();
  factory WeightService() => _instance;

  // 인메모리 데이터 저장소
  final List<WeightRecord> _records = [];

  /// 모든 체중 기록 조회
  List<WeightRecord> getWeightRecords() {
    return List.unmodifiable(_records);
  }

  /// 특정 날짜의 체중 기록 조회
  WeightRecord? getRecordByDate(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    try {
      return _records.firstWhere(
        (record) => _normalizeDate(record.date) == normalizedDate,
      );
    } catch (_) {
      return null;
    }
  }

  /// 체중 기록 저장 또는 수정
  /// - 동일 날짜 기록 존재 시 Update
  /// - 없으면 Insert
  Future<void> saveWeightRecord(WeightRecord record) async {
    final normalizedDate = _normalizeDate(record.date);
    final existingIndex = _records.indexWhere(
      (r) => _normalizeDate(r.date) == normalizedDate,
    );

    if (existingIndex != -1) {
      // Update
      _records[existingIndex] = record;
    } else {
      // Insert
      _records.add(record);
      // 날짜순 정렬
      _records.sort((a, b) => a.date.compareTo(b.date));
    }

    // 추후 Supabase 저장 로직 추가 예정
    // await _saveToSupabase(record);
  }

  /// 특정 날짜의 체중 기록 삭제
  Future<void> deleteWeightRecord(DateTime date) async {
    final normalizedDate = _normalizeDate(date);
    _records.removeWhere(
      (record) => _normalizeDate(record.date) == normalizedDate,
    );

    // 추후 Supabase 삭제 로직 추가 예정
    // await _deleteFromSupabase(date);
  }

  /// 날짜 정규화 (시간 정보 제거, 날짜만 비교)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 모든 데이터 클리어 (테스트용)
  void clearAllRecords() {
    _records.clear();
  }

  /// 특정 기간의 체중 기록 조회
  List<WeightRecord> getRecordsByDateRange(DateTime start, DateTime end) {
    final normalizedStart = _normalizeDate(start);
    final normalizedEnd = _normalizeDate(end);

    return _records.where((record) {
      final recordDate = _normalizeDate(record.date);
      return recordDate.isAfter(normalizedStart.subtract(const Duration(days: 1))) &&
          recordDate.isBefore(normalizedEnd.add(const Duration(days: 1)));
    }).toList();
  }
}
