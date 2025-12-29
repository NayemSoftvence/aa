package com.livekitCalling.livekit_calling_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.livekitCalling.app/ringtone"
    private lateinit var ringtoneManager: RingtoneManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        ringtoneManager = RingtoneManager(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playRingtone" -> {
                        ringtoneManager.playRingtone()
                        result.success(null)
                    }
                    "stopRingtone" -> {
                        ringtoneManager.stopRingtone()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

