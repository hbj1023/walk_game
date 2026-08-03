package com.hbj1023.walkmaster

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.floor

class OfflineAttackNotificationWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            applicationContext.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return Result.success()
        }

        val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val userId = prefs.getString(KEY_USER_ID, "")?.trim().orEmpty()
        val capacity = prefs.getInt(KEY_CAPACITY, 0)
        val currentBalance = prefs.getInt(KEY_CURRENT_BALANCE, 0)
        val attackDistanceM = prefs.getFloat(KEY_ATTACK_DISTANCE_M, 0f).toDouble()
        val remainderM = prefs.getFloat(KEY_REMAINDER_M, 0f).toDouble()
        if (userId.isEmpty() || capacity <= 0) {
            return Result.success()
        }

        val isFull = currentBalance >= capacity || projectedBalanceIsFull(
            userId = userId,
            currentBalance = currentBalance,
            capacity = capacity,
            attackDistanceM = attackDistanceM,
            remainderM = remainderM,
        )
        if (!isFull) return Result.success()

        val now = System.currentTimeMillis()
        val lastNotifiedAt = prefs.getLong(KEY_LAST_NOTIFIED_AT, 0L)
        if (lastNotifiedAt > 0L && now - lastNotifiedAt < REMINDER_INTERVAL_MS) {
            return Result.success()
        }
        if (!prefs.getBoolean(KEY_ALLOW_NIGHT_NOTIFICATIONS, false) && isQuietHours()) {
            return Result.success()
        }

        createNotificationChannel(applicationContext)
        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val isReminder = lastNotifiedAt > 0L
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(
                if (isReminder) "\uacf5\uaca9 \uae30\ud68c\uac00 \uac00\ub4dd \ucc28 \uc788\uc2b5\ub2c8\ub2e4"
                else "\uacf5\uaca9 \uae30\ud68c \ucda9\uc804 \uc644\ub8cc",
            )
            .setContentText(
                if (isReminder) "\uc804\ud22c\uc5d0\uc11c ${capacity}\ud68c\uc758 \uacf5\uaca9 \uae30\ud68c\ub97c \uc0ac\uc6a9\ud574 \uc8fc\uc138\uc694."
                else "\uc624\ud504\ub77c\uc778 \uacf5\uaca9 \uae30\ud68c\uac00 ${capacity}\ud68c \uac00\ub4dd \ucc3c\uc2b5\ub2c8\ub2e4.",
            )
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            applicationContext.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            NotificationManagerCompat.from(applicationContext).notify(NOTIFICATION_ID, notification)
            prefs.edit().putLong(KEY_LAST_NOTIFIED_AT, now).apply()
        }
        return Result.success()
    }

    private fun projectedBalanceIsFull(
        userId: String,
        currentBalance: Int,
        capacity: Int,
        attackDistanceM: Double,
        remainderM: Double,
    ): Boolean {
        if (attackDistanceM <= 0) return false
        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val accountBaselineKey = "$FLUTTER_ACCOUNT_BASELINE_PREFIX$userId"
        if (!flutterPrefs.contains(accountBaselineKey)) return false
        val baselineSteps = flutterPrefs.getLong(accountBaselineKey, -1L)
        val currentSteps = readCurrentStepCounter() ?: return false
        if (baselineSteps < 0 || currentSteps <= baselineSteps) return false

        val offlineDistanceM = (currentSteps - baselineSteps) * STRIDE_M + remainderM
        val earned = floor(offlineDistanceM / attackDistanceM).toInt()
        return currentBalance + earned >= capacity
    }

    private fun isQuietHours(): Boolean {
        val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        return hour >= QUIET_HOURS_START || hour < QUIET_HOURS_END
    }

    private fun readCurrentStepCounter(): Long? {
        val sensorManager = applicationContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return null
        val latch = CountDownLatch(1)
        var steps: Long? = null
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                steps = event.values.firstOrNull()?.toLong()
                latch.countDown()
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        if (!sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)) {
            return null
        }
        latch.await(5, TimeUnit.SECONDS)
        sensorManager.unregisterListener(listener)
        return steps
    }

    companion object {
        const val PREFS_NAME = "offline_attack_notification"
        const val KEY_USER_ID = "user_id"
        const val KEY_CURRENT_BALANCE = "current_balance"
        const val KEY_CAPACITY = "capacity"
        const val KEY_ATTACK_DISTANCE_M = "offline_attack_distance_m"
        const val KEY_REMAINDER_M = "attack_distance_remainder_m"
        const val KEY_LAST_NOTIFIED_AT = "last_notified_at"
        const val KEY_ALLOW_NIGHT_NOTIFICATIONS = "allow_night_notifications"
        private const val FLUTTER_ACCOUNT_BASELINE_PREFIX =
            "flutter.offline_steps.baseline."
        private const val STRIDE_M = 0.75
        private const val CHANNEL_ID = "offline_attack_full"
        private const val NOTIFICATION_ID = 1010
        private const val WORK_NAME = "offline_attack_capacity_check"
        private const val REMINDER_INTERVAL_MS = 5L * 60L * 60L * 1000L
        private const val QUIET_HOURS_START = 22
        private const val QUIET_HOURS_END = 8

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<OfflineAttackNotificationWorker>(
                15,
                TimeUnit.MINUTES,
            ).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        }

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "\uacf5\uaca9 \uae30\ud68c \ucda9\uc804",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "\uc624\ud504\ub77c\uc778 \uacf5\uaca9 \uae30\ud68c\uac00 \uac00\ub4dd \ucc28\uba74 \uc54c\ub824\uc90d\ub2c8\ub2e4."
                },
            )
        }
    }
}
