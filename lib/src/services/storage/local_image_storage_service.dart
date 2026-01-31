import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 이미지 소유자 타입 상수
class ImageOwnerType {
  static const userProfile = 'user_profile';
  static const petProfile = 'pet_profile';
  static const healthCheck = 'health_check';
}

/// SQLite 기반 로컬 이미지 저장 서비스
class LocalImageStorageService {
  static const _dbName = 'perch_care_images.db';
  static const _dbVersion = 1;
  static const _tableName = 'local_images';

  static LocalImageStorageService? _instance;
  static LocalImageStorageService get instance =>
      _instance ??= LocalImageStorageService._();

  LocalImageStorageService._();

  Database? _db;

  /// 앱 시작 시 호출 (main.dart)
  Future<void> init() async {
    if (_db != null) return;

    // macOS/Linux/Windows 데스크톱에서는 FFI 사용
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_type TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        image_bytes BLOB NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_owner
      ON $_tableName(owner_type, owner_id)
    ''');
  }

  /// 이미지 저장 (기존 이미지가 있으면 덮어쓰기)
  Future<void> saveImage({
    required String ownerType,
    required String ownerId,
    required Uint8List imageBytes,
  }) async {
    await _db!.insert(
      _tableName,
      {
        'owner_type': ownerType,
        'owner_id': ownerId,
        'image_bytes': imageBytes,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 이미지 조회 (없으면 null)
  Future<Uint8List?> getImage({
    required String ownerType,
    required String ownerId,
  }) async {
    final rows = await _db!.query(
      _tableName,
      columns: ['image_bytes'],
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: [ownerType, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['image_bytes'] as Uint8List?;
  }

  /// 특정 이미지 삭제
  Future<void> deleteImage({
    required String ownerType,
    required String ownerId,
  }) async {
    await _db!.delete(
      _tableName,
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: [ownerType, ownerId],
    );
  }

  /// 특정 타입의 모든 이미지 삭제
  Future<void> deleteAllByType(String ownerType) async {
    await _db!.delete(
      _tableName,
      where: 'owner_type = ?',
      whereArgs: [ownerType],
    );
  }

  /// 전체 이미지 삭제 (로그아웃/탈퇴 시)
  Future<void> clearAll() async {
    await _db!.delete(_tableName);
  }
}
