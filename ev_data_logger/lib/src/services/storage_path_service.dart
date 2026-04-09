import 'dart:io';

import 'package:flutter/services.dart';

class StoragePathConfig {
  const StoragePathConfig({required this.rootPath, this.legacyPath});

  final String rootPath;
  final String? legacyPath;
}

class StoragePathService {
  StoragePathService._();

  static const MethodChannel _channel = MethodChannel(
    'ev_data_logger/storage_path',
  );

  static Future<StoragePathConfig> resolve() async {
    final dynamic result = await _channel.invokeMethod<dynamic>(
      'getStoragePaths',
    );
    if (result is! Map) {
      throw Exception('Invalid storage path payload from platform channel.');
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(result);
    final String rootPath = (map['rootPath'] as String?) ?? '';
    final String? legacyPath = map['legacyPath'] as String?;
    if (rootPath.isEmpty) {
      throw Exception('Empty rootPath from platform channel.');
    }

    final StoragePathConfig config = StoragePathConfig(
      rootPath: rootPath,
      legacyPath: legacyPath,
    );
    await _migrateLegacyDataIfNeeded(config);
    return config;
  }

  static Future<void> _migrateLegacyDataIfNeeded(StoragePathConfig cfg) async {
    final Directory target = Directory(cfg.rootPath);
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    final String? legacyPath = cfg.legacyPath;
    if (legacyPath == null || legacyPath.isEmpty) {
      return;
    }

    final Directory legacy = Directory(legacyPath);
    if (!await legacy.exists()) {
      return;
    }

    // Migrate only once by dropping a marker after copy completes.
    final File marker = File('${target.path}/.legacy_migrated');
    if (await marker.exists()) {
      return;
    }

    final List<FileSystemEntity> entities = await legacy.list().toList();
    for (final FileSystemEntity entity in entities) {
      final String name = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;
      if (name.isEmpty) {
        continue;
      }
      await _copyEntity(entity, '${target.path}/$name');
    }

    await marker.writeAsString(DateTime.now().toUtc().toIso8601String());
  }

  static Future<void> _copyEntity(FileSystemEntity source, String dest) async {
    if (source is File) {
      final File destination = File(dest);
      final Directory parent = destination.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      if (!await destination.exists()) {
        await source.copy(destination.path);
      }
      return;
    }

    if (source is Directory) {
      final Directory destination = Directory(dest);
      if (!await destination.exists()) {
        await destination.create(recursive: true);
      }
      await for (final FileSystemEntity child in source.list(
        recursive: false,
      )) {
        final String childName = child.uri.pathSegments.last;
        await _copyEntity(child, '${destination.path}/$childName');
      }
    }
  }
}

class AppStorage {
  AppStorage._();

  static String? _rootPath;

  static String get rootPath {
    final String? value = _rootPath;
    if (value == null || value.isEmpty) {
      throw StateError('AppStorage is not initialized.');
    }
    return value;
  }

  static bool get isInitialized => _rootPath != null && _rootPath!.isNotEmpty;

  static Future<void> initialize() async {
    if (isInitialized) {
      return;
    }
    final StoragePathConfig config = await StoragePathService.resolve();
    _rootPath = config.rootPath;
  }
}
