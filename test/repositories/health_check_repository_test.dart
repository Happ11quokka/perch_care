import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/repositories/health_check_repository.dart';
import 'package:perch_care/src/services/health_check/health_check_service.dart';
import 'package:perch_care/src/services/storage/health_check_storage_service.dart';
import 'package:perch_care/src/services/storage/local_image_storage_service.dart';

class MockHealthCheckService extends Mock implements HealthCheckService {}

class MockHealthCheckStorageService extends Mock
    implements HealthCheckStorageService {}

class MockLocalImageStorageService extends Mock
    implements LocalImageStorageService {}

HealthCheckRecord _record({String? petId, String id = 'rec-1'}) {
  return HealthCheckRecord(
    id: id,
    petId: petId,
    mode: 'full_body',
    imageUrl: null,
    result: const {'overall_status': 'normal'},
    confidenceScore: 0.9,
    status: 'normal',
    checkedAt: DateTime(2026, 7, 1),
  );
}

void main() {
  late MockHealthCheckService service;
  late MockHealthCheckStorageService storage;
  late MockLocalImageStorageService imageStorage;
  late HealthCheckRepository repo;

  setUpAll(() {
    registerFallbackValue(_record());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    service = MockHealthCheckService();
    storage = MockHealthCheckStorageService();
    imageStorage = MockLocalImageStorageService();
    repo = HealthCheckRepositoryImpl(
      service: service,
      storage: storage,
      imageStorage: imageStorage,
    );
  });

  group('analyze', () {
    test('delegates to service.analyzeImage', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(() => service.analyzeImage(
            petId: any(named: 'petId'),
            mode: any(named: 'mode'),
            part: any(named: 'part'),
            notes: any(named: 'notes'),
            language: any(named: 'language'),
            imageBytes: any(named: 'imageBytes'),
            fileName: any(named: 'fileName'),
          )).thenAnswer((_) async => {'overall_status': 'normal'});

      final result = await repo.analyze(
        petId: 'pet-1',
        mode: 'full_body',
        part: 'wing',
        notes: 'note',
        language: 'ko',
        imageBytes: bytes,
        fileName: 'a.jpg',
      );

      expect(result, {'overall_status': 'normal'});
      verify(() => service.analyzeImage(
            petId: 'pet-1',
            mode: 'full_body',
            part: 'wing',
            notes: 'note',
            language: 'ko',
            imageBytes: bytes,
            fileName: 'a.jpg',
          )).called(1);
    });
  });

  group('analyzeFood', () {
    test('delegates to service.analyzeFood', () async {
      final bytes = Uint8List.fromList([4, 5, 6]);
      when(() => service.analyzeFood(
            notes: any(named: 'notes'),
            language: any(named: 'language'),
            imageBytes: any(named: 'imageBytes'),
            fileName: any(named: 'fileName'),
          )).thenAnswer((_) async => {'overall_diet_assessment': 'good'});

      final result = await repo.analyzeFood(
        notes: 'n',
        language: 'en',
        imageBytes: bytes,
        fileName: 'food.jpg',
      );

      expect(result, {'overall_diet_assessment': 'good'});
      verify(() => service.analyzeFood(
            notes: 'n',
            language: 'en',
            imageBytes: bytes,
            fileName: 'food.jpg',
          )).called(1);
    });
  });

  group('loadHistory', () {
    test('server success returns server records and refreshes cache',
        () async {
      final serverRecords = [_record(petId: 'pet-1', id: 'server-1')];
      when(() => storage.fetchFromServer('pet-1'))
          .thenAnswer((_) async => serverRecords);
      when(() => storage.syncWithServer('pet-1')).thenAnswer((_) async {});

      final result = await repo.loadHistory('pet-1');

      expect(result, serverRecords);
      verify(() => storage.fetchFromServer('pet-1')).called(1);
      verify(() => storage.syncWithServer('pet-1')).called(1);
      verifyNever(() => storage.getRecords(any()));
    });

    test('server failure falls back to local cache', () async {
      when(() => storage.fetchFromServer('pet-1'))
          .thenThrow(Exception('network error'));
      final localRecords = [_record(petId: 'pet-1', id: 'local-1')];
      when(() => storage.getRecords('pet-1'))
          .thenAnswer((_) async => localRecords);

      final result = await repo.loadHistory('pet-1');

      expect(result, localRecords);
      verify(() => storage.getRecords('pet-1')).called(1);
      verifyNever(() => storage.syncWithServer(any()));
    });

    test('syncWithServer failure (after successful fetch) still falls back '
        'to local cache', () async {
      final serverRecords = [_record(petId: 'pet-1', id: 'server-1')];
      when(() => storage.fetchFromServer('pet-1'))
          .thenAnswer((_) async => serverRecords);
      when(() => storage.syncWithServer('pet-1'))
          .thenThrow(Exception('sync failed'));
      final localRecords = [_record(petId: 'pet-1', id: 'local-1')];
      when(() => storage.getRecords('pet-1'))
          .thenAnswer((_) async => localRecords);

      final result = await repo.loadHistory('pet-1');

      expect(result, localRecords);
    });
  });

  group('delete', () {
    test('with petId: deletes local record, local image, and server record',
        () async {
      final record = _record(petId: 'pet-1', id: 'rec-1');
      when(() => storage.deleteRecord('pet-1', 'rec-1'))
          .thenAnswer((_) async {});
      when(() => imageStorage.deleteImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
          )).thenAnswer((_) async {});
      when(() => service.deleteHealthCheck('rec-1', petId: 'pet-1'))
          .thenAnswer((_) async {});

      await repo.delete(record);

      verify(() => storage.deleteRecord('pet-1', 'rec-1')).called(1);
      verify(() => imageStorage.deleteImage(
            ownerType: ImageOwnerType.healthCheck,
            ownerId: 'rec-1',
          )).called(1);
      verify(() => service.deleteHealthCheck('rec-1', petId: 'pet-1'))
          .called(1);
    });

    test('server delete failure is swallowed (best-effort)', () async {
      final record = _record(petId: 'pet-1', id: 'rec-1');
      when(() => storage.deleteRecord('pet-1', 'rec-1'))
          .thenAnswer((_) async {});
      when(() => imageStorage.deleteImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
          )).thenAnswer((_) async {});
      when(() => service.deleteHealthCheck('rec-1', petId: 'pet-1'))
          .thenThrow(Exception('server error'));

      await expectLater(repo.delete(record), completes);
    });

    test('with null petId (food/global mode): skips server delete',
        () async {
      final record = _record(petId: null, id: 'rec-2');
      when(() => storage.deleteRecord(null, 'rec-2')).thenAnswer((_) async {});
      when(() => imageStorage.deleteImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
          )).thenAnswer((_) async {});

      await repo.delete(record);

      verify(() => storage.deleteRecord(null, 'rec-2')).called(1);
      verify(() => imageStorage.deleteImage(
            ownerType: ImageOwnerType.healthCheck,
            ownerId: 'rec-2',
          )).called(1);
      verifyNever(() => service.deleteHealthCheck(any(), petId: any(named: 'petId')));
    });
  });

  group('saveLocalMirror', () {
    test('with imageBytes: saves record and image', () async {
      final record = _record(id: 'rec-3');
      final bytes = Uint8List.fromList([7, 8, 9]);
      when(() => storage.saveRecord(any())).thenAnswer((_) async {});
      when(() => imageStorage.saveImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            imageBytes: any(named: 'imageBytes'),
          )).thenAnswer((_) async {});

      await repo.saveLocalMirror(record, bytes);

      verify(() => storage.saveRecord(record)).called(1);
      verify(() => imageStorage.saveImage(
            ownerType: ImageOwnerType.healthCheck,
            ownerId: 'rec-3',
            imageBytes: bytes,
          )).called(1);
    });

    test('without imageBytes: saves record only, does not save image',
        () async {
      final record = _record(id: 'rec-4');
      when(() => storage.saveRecord(any())).thenAnswer((_) async {});

      await repo.saveLocalMirror(record, null);

      verify(() => storage.saveRecord(record)).called(1);
      verifyNever(() => imageStorage.saveImage(
            ownerType: any(named: 'ownerType'),
            ownerId: any(named: 'ownerId'),
            imageBytes: any(named: 'imageBytes'),
          ));
    });
  });
}
