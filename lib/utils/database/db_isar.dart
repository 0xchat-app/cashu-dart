import 'dart:async';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class CashuIsarDB {
  static final CashuIsarDB shared = CashuIsarDB._internal();
  CashuIsarDB._internal();
  factory CashuIsarDB() => shared;

  late Isar isar;

  bool get isOpen => isar.isOpen;

  List<CollectionSchema<dynamic>> schemas = [];

  Future open(String dbName) async {
    Directory directory;
    if (Platform.isAndroid) {
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      directory = await getApplicationSupportDirectory();
    } else {
      throw Exception('Unsupported platform');
    }
    final dbPath = directory.path;
    isar = Isar.getInstance(dbName) ?? await Isar.open(
      schemas,
      directory: dbPath,
      name: dbName,
    );
  }

  Future<void> closeDatabase() async {
    if (isar.isOpen) await isar.close();
  }

  Future<Id> put<T>(T object) async {
    return await isar.writeTxn(() async {
      return await isar.collection<T>().put(object);
    });
  }

  Future<List<Id>> putAll<T>(List<T> objects) async {
    return await isar.writeTxn(() async {
      final collection = isar.collection<T>();
      return await collection.putAll(objects);
    });
  }

  Future<List<T>> getAll<T>() async {
    return isar.collection<T>().where().findAll();
  }

  QueryBuilder<T, T, QWhere> _buildBaseQuery<T>(
    QueryBuilder<T, T, QWhere> Function(QueryBuilder<T, T, QWhere>) filter, {
    int? limit,
    int? offset,
  }) {
    final query = filter(isar.collection<T>().where());

    if (limit != null) query.limit(limit);
    if (offset != null) query.offset(offset);

    return query;
  }

  /// Query multiple records
  ///
  /// **Implementation:**
  /// 1. Execute the provided [filter] function to build the base query
  /// 2. Optionally apply [limit] and [offset] for pagination
  ///
  /// **Note:**
  /// This method is for simple queries. For more complex queries (like multiple filters, advanced sorting),
  /// please use Isar's query builder directly for custom queries.
  ///
  /// Example usage:
  /// ```dart
  /// final result = await query<MyModel>((q) => q.nameEqualTo('Alice'), limit: 10, offset: 0);
  /// ```
  /// - [T]: Type of query result
  /// - [filter]: Function using [QueryBuilder] to build the query
  /// - [limit]: Optional limit on number of results
  /// - [offset]: Optional pagination offset
  Future<List<T>> query<T>(
    QueryBuilder<T, T, QWhere> Function(QueryBuilder<T, T, QWhere>) filter, {
    int? limit,
    int? offset,
  }) async {
    final query = _buildBaseQuery(filter, limit: limit, offset: offset);
    return query.findAll();
  }

  /// Query single record
  ///
  /// Similar to [query] method, but only returns the first matching record
  ///
  /// **Implementation:**
  /// 1. Execute the provided [filter] function to build the base query
  /// 2. Return the first matching record, or null if no match is found
  ///
  /// Example usage:
  /// ```dart
  /// final result = await queryFirst<MyModel>((q) => q.nameEqualTo('Alice'));
  /// ```
  Future<T?> queryFirst<T>(
    QueryBuilder<T, T, QWhere> Function(QueryBuilder<T, T, QWhere>) filter,
  ) async {
    final query = _buildBaseQuery(filter);
    return query.findFirst();
  }

  Future<void> delete<T>(Id id) async {
    await isar.writeTxn(() async {
      await isar.collection<T>().delete(id);
    });
  }

  Future<void> deleteWhere<T>(
      QueryBuilder<T, T, QWhere> Function(QueryBuilder<T, T, QWhere>) filter,
      ) async {
    await isar.writeTxn(() async {
      final query = filter(isar.collection<T>().where());
      await query.deleteAll();
    });
  }

  Future<void> clearAll() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  }
}
