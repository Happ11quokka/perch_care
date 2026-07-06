import 'package:flutter_test/flutter_test.dart';

import 'package:perch_care/src/view_models/auth/post_login_destination.dart';

void main() {
  group('destinationForHasPets', () {
    test('hasPets == true → home', () {
      expect(destinationForHasPets(true), PostLoginDestination.home);
    });

    test('hasPets == false → onboarding', () {
      expect(destinationForHasPets(false), PostLoginDestination.onboarding);
    });

    test('hasPets == null (조회 실패) → home (안전 분기)', () {
      expect(destinationForHasPets(null), PostLoginDestination.home);
    });
  });
}
