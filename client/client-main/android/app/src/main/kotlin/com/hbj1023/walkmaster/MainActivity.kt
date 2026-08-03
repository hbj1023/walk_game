package com.hbj1023.walkmaster

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val activityPermissionChannel = "cap1/activity_permission"
    private val offlineNotificationChannel = "cap1/offline_attack_notification"
    private val activityRecognitionRequestCode = 4901
    private val notificationPermissionRequestCode = 4902
    private var pendingActivityPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            activityPermissionChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkActivityRecognitionPermission" -> result.success(
                    hasActivityRecognitionPermission()
                )
                "ensureActivityRecognitionPermission" -> ensureActivityRecognitionPermission(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            offlineNotificationChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureNotificationPermission" -> ensureNotificationPermission(result)
                "configure" -> {
                    configureOfflineNotification(
                        userId = call.argument<String>("userId") ?: "",
                        currentBalance = (call.argument<Number>("currentBalance") ?: 0).toInt(),
                        capacity = (call.argument<Number>("capacity") ?: 0).toInt(),
                        attackDistanceM = (call.argument<Number>("offlineAttackDistanceM") ?: 0).toFloat(),
                        remainderM = (call.argument<Number>("attackDistanceRemainderM") ?: 0).toFloat(),
                    )
                    result.success(null)
                }
                "clear" -> {
                    clearOfflineNotification()
                    result.success(null)
                }
                "updateBalance" -> {
                    updateOfflineNotificationBalance(
                        (call.argument<Number>("currentBalance") ?: 0).toInt(),
                    )
                    result.success(null)
                }
                "updatePreferences" -> {
                    updateOfflineNotificationPreferences(
                        call.argument<Boolean>("allowNightNotifications") ?: false,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        OfflineAttackNotificationWorker.createNotificationChannel(this)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingNotificationPermissionResult != null) {
            result.error(
                "permission_request_active",
                "Notification permission request is already active.",
                null,
            )
            return
        }
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode,
        )
    }

    private fun configureOfflineNotification(
        userId: String,
        currentBalance: Int,
        capacity: Int,
        attackDistanceM: Float,
        remainderM: Float,
    ) {
        val prefs = getSharedPreferences(
            OfflineAttackNotificationWorker.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        prefs.edit()
            .putString(OfflineAttackNotificationWorker.KEY_USER_ID, userId.trim())
            .putInt(OfflineAttackNotificationWorker.KEY_CURRENT_BALANCE, currentBalance)
            .putInt(OfflineAttackNotificationWorker.KEY_CAPACITY, capacity)
            .putFloat(OfflineAttackNotificationWorker.KEY_ATTACK_DISTANCE_M, attackDistanceM)
            .putFloat(OfflineAttackNotificationWorker.KEY_REMAINDER_M, remainderM)
            .apply()
        if (currentBalance < capacity) {
            prefs.edit()
                .remove(OfflineAttackNotificationWorker.KEY_LAST_NOTIFIED_AT)
                .apply()
        }
        OfflineAttackNotificationWorker.createNotificationChannel(this)
        OfflineAttackNotificationWorker.schedule(this)
    }

    private fun clearOfflineNotification() {
        getSharedPreferences(
            OfflineAttackNotificationWorker.PREFS_NAME,
            Context.MODE_PRIVATE,
        ).edit().clear().apply()
        OfflineAttackNotificationWorker.cancel(this)
    }

    private fun updateOfflineNotificationBalance(currentBalance: Int) {
        val prefs = getSharedPreferences(
            OfflineAttackNotificationWorker.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val capacity = prefs.getInt(OfflineAttackNotificationWorker.KEY_CAPACITY, 0)
        val editor = prefs.edit().putInt(
            OfflineAttackNotificationWorker.KEY_CURRENT_BALANCE,
            currentBalance,
        )
        if (capacity > 0 && currentBalance < capacity) {
            editor.remove(OfflineAttackNotificationWorker.KEY_LAST_NOTIFIED_AT)
        }
        editor.apply()
    }

    private fun updateOfflineNotificationPreferences(allowNightNotifications: Boolean) {
        getSharedPreferences(
            OfflineAttackNotificationWorker.PREFS_NAME,
            Context.MODE_PRIVATE,
        ).edit()
            .putBoolean(
                OfflineAttackNotificationWorker.KEY_ALLOW_NIGHT_NOTIFICATIONS,
                allowNightNotifications,
            )
            .apply()
    }

    private fun ensureActivityRecognitionPermission(result: MethodChannel.Result) {
        if (hasActivityRecognitionPermission()) {
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

    private fun hasActivityRecognitionPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            activityRecognitionRequestCode -> {
                pendingActivityPermissionResult?.success(granted)
                pendingActivityPermissionResult = null
            }
            notificationPermissionRequestCode -> {
                pendingNotificationPermissionResult?.success(granted)
                pendingNotificationPermissionResult = null
            }
        }
    }
}
