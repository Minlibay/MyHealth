package com.myhealth.myhealth

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (вместо FlutterActivity) обязателен для пакета `health`:
// flow разрешений Google Health Connect требует именно FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private var ring: RingBleManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val ble = RingBleManager(applicationContext)
        ring = ble

        EventChannel(messenger, "jcring_x3/events").setStreamHandler(ble)

        MethodChannel(messenger, "jcring_x3/methods").setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> { ble.startScan(); result.success(null) }
                "stopScan" -> { ble.stopScan(); result.success(null) }
                "connect" -> {
                    ble.connect(
                        call.argument<String>("id")!!,
                        call.argument<Boolean>("auto") ?: false,
                    )
                    result.success(null)
                }
                "disconnect" -> { ble.disconnect(); result.success(null) }
                "measure" -> { ble.measure(); result.success(null) }
                "syncHistory" -> { ble.syncHistory(); result.success(null) }
                "setProfile" -> {
                    ble.setProfile(
                        call.argument<Int>("gender") ?: 1,
                        call.argument<Int>("age") ?: 30,
                        call.argument<Int>("height") ?: 175,
                        call.argument<Int>("weight") ?: 70,
                    )
                    result.success(null)
                }
                "enableAutoMonitoring" -> {
                    ble.enableAutoMonitoring(call.argument<Int>("intervalMinutes") ?: 15)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
