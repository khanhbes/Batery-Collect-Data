package com.evlogger.ev_data_logger

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	private val storageChannel = "ev_data_logger/storage_path"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
			.setMethodCallHandler { call, result ->
				if (call.method == "getStoragePaths") {
					val rootDir = File(filesDir, "ev_logger_data")
					if (!rootDir.exists()) {
						rootDir.mkdirs()
					}
					val legacyDir = File(applicationInfo.dataDir, "app_flutter")
					result.success(
						mapOf(
							"rootPath" to rootDir.absolutePath,
							"legacyPath" to legacyDir.absolutePath,
						)
					)
				} else {
					result.notImplemented()
				}
			}
	}
}
