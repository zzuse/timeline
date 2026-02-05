package com.zzuse.timeline

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.zzuse.timeline/deeplink"
    private val TAG = "MainActivity"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate called")
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called")
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        Log.d(TAG, "handleIntent called - intent: $intent")
        val data = intent?.data
        Log.d(TAG, "Intent data: $data")
        
        if (data != null) {
            Log.d(TAG, "Data scheme: ${data.scheme}, host: ${data.host}, path: ${data.path}")
            
            if (data.scheme == "com.zzuse.timeline" && data.host == "auth") {
                Log.d(TAG, "Deep link matched! Sending to Flutter...")
                // Create method channel to send deep link to Flutter
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL).invokeMethod("onDeepLink", data.toString())
                    Log.d(TAG, "Deep link sent via MethodChannel: ${data.toString()}")
                } ?: Log.e(TAG, "Flutter engine not ready!")
            } else {
                Log.d(TAG, "Deep link did not match - expected com.zzuse.timeline://auth")
            }
        } else {
            Log.d(TAG, "No intent data")
        }
    }
}
