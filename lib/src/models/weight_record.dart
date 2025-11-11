class WeightRecord {
  final DateTime date;
  final double weight; // in grams

  const WeightRecord({
    required this.date,
    required this.weight,
  });
}

// 더미 데이터 (샘플 데이터)
class WeightData {
  // 현재 월 데이터 가져오기 (더 많은 더미 데이터 추가)
  static List<WeightRecord> getCurrentMonthData() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // 최근 6개월 동안의 더미 데이터 생성 (차트용)
    final List<WeightRecord> records = [];

    // 6개월 전부터 데이터 추가
    for (int monthOffset = 5; monthOffset >= 0; monthOffset--) {
      final targetMonth = month - monthOffset;
      if (targetMonth < 1) continue; // 1월 이전은 건너뛰기

      // 각 월마다 8~12개 정도의 기록 추가
      final baseWeight = 52.0 + (targetMonth * 0.6);

      records.add(WeightRecord(date: DateTime(year, targetMonth, 2), weight: baseWeight + 0.2));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 5), weight: baseWeight + 0.5));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 8), weight: baseWeight + 0.8));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 11), weight: baseWeight + 1.0));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 14), weight: baseWeight + 1.2));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 17), weight: baseWeight + 1.5));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 20), weight: baseWeight + 1.8));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 23), weight: baseWeight + 2.0));

      // 현재 월이고 오늘 날짜보다 이후면 추가 안 함
      if (targetMonth == month && 26 <= now.day) {
        records.add(WeightRecord(date: DateTime(year, targetMonth, 26), weight: baseWeight + 2.2));
      }
      if (targetMonth == month && 29 <= now.day) {
        records.add(WeightRecord(date: DateTime(year, targetMonth, 29), weight: baseWeight + 2.5));
      }
    }

    return records;
  }

  // 9월 데이터 (하위 호환성 유지)
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

  // 월별 평균 데이터 (차트용 - 최근 6개월)
  static Map<int, double> getMonthlyAverages() {
    final now = DateTime.now();
    final currentMonth = now.month;

    // 현재 월 기준 최근 6개월 데이터
    final Map<int, double> data = {};

    for (int i = 5; i >= 0; i--) {
      final month = currentMonth - i;
      if (month >= 1 && month <= 12) {
        // 간단한 증가 패턴 (실제로는 DB에서 가져옴)
        data[month] = 52.0 + (month * 0.5);
      }
    }

    return data;
  }

  // 주간 데이터 (현재 월 기준, 월~일)
  // weekNumber: 1 = 1주차, 2 = 2주차, ...
  static Map<int, Map<int, double>> getWeeklyData() {
    final now = DateTime.now();
    final baseWeight = 52.0 + (now.month * 0.5); // 현재 월 기준 체중

    return {
      1: {
        1: baseWeight + 0.2,
        2: baseWeight + 0.4,
        3: baseWeight + 0.6,
        4: baseWeight + 0.8,
        5: baseWeight + 0.5,
        6: baseWeight + 1.0,
        7: baseWeight + 0.8
      },
      2: {
        1: baseWeight + 1.2,
        2: baseWeight + 1.5,
        3: baseWeight + 1.3,
        4: baseWeight + 1.7,
        5: baseWeight + 1.4,
        6: baseWeight + 1.9,
        7: baseWeight + 1.6
      },
      3: {
        1: baseWeight + 1.8,
        2: baseWeight + 2.0,
        3: baseWeight + 2.2,
        4: baseWeight + 2.1,
        5: baseWeight + 2.3,
        6: baseWeight + 2.5,
        7: baseWeight + 2.4
      },
      4: {
        1: baseWeight + 2.6,
        2: baseWeight + 2.8,
        3: baseWeight + 2.7,
        4: baseWeight + 3.0,
        5: baseWeight + 2.9,
        6: baseWeight + 3.2,
        7: baseWeight + 3.1
      },
    };
  }

  // 연간 데이터 (2025년 기준, 1~12월)
  static Map<int, double> getYearlyAverages(int year) {
    if (year == 2025) {
      return {
        1: 48.5,
        2: 49.2,
        3: 50.1,
        4: 50.8,
        5: 51.5,
        6: 52.5,
        7: 54.2,
        8: 55.8,
        9: 57.2,
        10: 0.0, // 미래
        11: 0.0,
        12: 0.0,
      };
    }
    // 다른 년도는 빈 데이터
    return {};
  }

  // 주차별 평균 계산
  static Map<int, double> getWeeklyAverages(int weekNumber) {
    final weekData = getWeeklyData()[weekNumber];
    if (weekData == null) return {};
    return weekData;
  }
}
