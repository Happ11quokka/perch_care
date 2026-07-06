import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/repositories/report_share_repository.dart';
import 'package:perch_care/src/services/api/api_client.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;
  late ReportShareRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = ReportShareRepositoryImpl(api: api);
  });

  test(
      'shareHealthReport posts to /reports/share/health/{petId} '
      'with date_from/date_to query params and returns share_url', () async {
    when(() => api.post(any()))
        .thenAnswer((_) async => {'share_url': 'https://perchcare.app/s/abc'});

    final result = await repo.shareHealthReport(
      petId: 'pet-1',
      from: DateTime(2026, 6, 6),
      to: DateTime(2026, 7, 6),
    );

    expect(result, 'https://perchcare.app/s/abc');
    final captured = verify(() => api.post(captureAny())).captured;
    expect(captured, hasLength(1));
    expect(
      captured.single,
      '/reports/share/health/pet-1?date_from=2026-06-06&date_to=2026-07-06',
    );
  });

  test(
      'shareVetSummary posts to /reports/share/vet-summary/{petId} '
      'and returns share_url', () async {
    when(() => api.post(any()))
        .thenAnswer((_) async => {'share_url': 'https://perchcare.app/s/xyz'});

    final result = await repo.shareVetSummary(petId: 'pet-1');

    expect(result, 'https://perchcare.app/s/xyz');
    verify(() => api.post('/reports/share/vet-summary/pet-1')).called(1);
  });

  test('shareHealthReport propagates ApiClient errors', () async {
    when(() => api.post(any())).thenThrow(
      ApiException(statusCode: 500, message: 'boom'),
    );

    await expectLater(
      repo.shareHealthReport(
        petId: 'pet-1',
        from: DateTime(2026, 6, 6),
        to: DateTime(2026, 7, 6),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('shareVetSummary propagates ApiClient errors', () async {
    when(() => api.post(any())).thenThrow(
      ApiException(statusCode: 500, message: 'boom'),
    );

    await expectLater(
      repo.shareVetSummary(petId: 'pet-1'),
      throwsA(isA<ApiException>()),
    );
  });
}
