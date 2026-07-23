import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'deepseek_service.dart';

/// ============================================================
/// SQLite 记忆库 — 存储互动历史 + 日记
/// ============================================================

class MemoryBank {
  static Database? _db;

  /// 初始化数据库
  static Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'mochi_memory.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_said TEXT NOT NULL,
            mood TEXT NOT NULL,
            time_label TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE diary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            content TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// 添加一条记忆
  static Future<void> addMemory(MemoryEntry entry) async {
    final db = await _database();
    await db.insert('memories', entry.toJson());
    // 保持最多 200 条
    await _trim(db, 200);
  }

  /// 获取最近 N 条记忆
  static Future<List<MemoryEntry>> getRecent(int count) async {
    final db = await _database();
    final rows = await db.query('memories',
        orderBy: 'id DESC', limit: count);
    return rows.map((r) => MemoryEntry.fromJson(r)).toList().reversed.toList();
  }

  /// 获取今天的所有记忆（用于日记压缩）
  static Future<List<MemoryEntry>> getToday() async {
    final db = await _database();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.query('memories',
        where: "timestamp LIKE ?", whereArgs: ['$today%'],
        orderBy: 'id ASC');
    return rows.map((r) => MemoryEntry.fromJson(r)).toList();
  }

  /// 保存日记
  static Future<void> saveDiary(String date, String content) async {
    final db = await _database();
    await db.insert('diary', {'date': date, 'content': content},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 获取今天的日记
  static Future<String?> getTodayDiary() async {
    final db = await _database();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.query('diary',
        where: 'date = ?', whereArgs: [today]);
    return rows.isNotEmpty ? rows.first['content'] as String? : null;
  }

  /// 获取上次日记日期
  static Future<String?> getLastDiaryDate() async {
    final db = await _database();
    final rows = await db.query('diary',
        orderBy: 'date DESC', limit: 1);
    return rows.isNotEmpty ? rows.first['date'] as String? : null;
  }

  static Future<void> _trim(Database db, int max) async {
    final count = (await db.rawQuery('SELECT COUNT(*) as c FROM memories'))
            .first['c'] as int;
    if (count > max) {
      await db.rawDelete(
          'DELETE FROM memories WHERE id NOT IN (SELECT id FROM memories ORDER BY id DESC LIMIT $max)');
    }
  }
}
