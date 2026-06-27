package com.example.capstone_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val activityPermissionChannel = "cap1/activity_permission"
    private val activityRecognitionRequestCode = 4901
    private var pendingActivityPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            activityPermissionChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureActivityRecognitionPermission" -> ensureActivityRecognitionPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureActivityRecognitionPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(true)
            return
        }

        if (checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        if (pendingActivityPermissionResult != null) {
            result.error(
                "permission_request_active",
                "Activity recognition permission request is already active.",
                null
            )
            return
        }

        pendingActivityPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            activityRecognitionRequestCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != activityRecognitionRequestCode) return

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingActivityPermissionResult?.success(granted)
        pendingActivityPermissionResult = null
    }
}
