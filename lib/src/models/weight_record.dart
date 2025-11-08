class WeightRecord {
  final DateTime date;
  final double weight; // in grams

  const WeightRecord({
    required this.date,
    required this.weight,
  });
}

// 9월 더미 데이터 (샘플 데이터)
class WeightData {
  static List<WeightRecord> getSeptemberData() {
    return [
      WeightRecord(date: DateTime(2025, 9, 3), weight: 55.2),
      WeightRecord(date: DateTime(2025, 9, 4), weight: 55.8),
      WeightRecord(date: DateTime(2025, 9, 6), weight: 56.1),
      WeightRecord(date: DateTime(2025, 9, 9), weight: 56.5),
      WeightRecord(date: DateTime(2025, 9, 11), weight: 56.3),
      WeightRecord(date: DateTime(2025, 9, 13), weight: 56.9),
      WeightRecord(date: DateTime(2025, 9, 15), weight: 57.0),
      WeightRecord(date: DateTime(2025, 9, 18), weight: 57.2),
      WeightRecord(date: DateTime(2025, 9, 20), weight: 57.5),
      WeightRecord(date: DateTime(2025, 9, 23), weight: 57.8),
      WeightRecord(date: DateTime(2025, 9, 26), weight: 58.0),
      WeightRecord(date: DateTime(2025, 9, 28), weight: 57.9),
    ];
  }

  // 월별 평균 데이터 (차트용)
  static Map<int, double> getMonthlyAverages() {
    return {
      6: 52.5,
      7: 54.2,
      8: 55.8,
      9: 57.2,
      10: 0.0, // 미래 데이터
      11: 0.0,
    };
  }
}
