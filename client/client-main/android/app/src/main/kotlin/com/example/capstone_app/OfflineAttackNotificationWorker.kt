package com.example.capstone_app

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
        val capacity = prefs.getInt(KEY_CAPACITY, 0)
        val currentBalance = prefs.getInt(KEY_CURRENT_BALANCE, 0)
        val attackDistanceM = prefs.getFloat(KEY_ATTACK_DISTANCE_M, 0f).toDouble()
        val remainderM = prefs.getFloat(KEY_REMAINDER_M, 0f).toDouble()
        if (capacity <= 0 || currentBalance >= capacity || attackDistanceM <= 0) {
            return Result.success()
        }

        val flutterPrefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        if (!flutterPrefs.contains(FLUTTER_LAST_SENSOR_STEPS)) return Result.success()
        val baselineSteps = flutterPrefs.getLong(FLUTTER_LAST_SENSOR_STEPS, -1L)
        val currentSteps = readCurrentStepCounter() ?: return Result.retry()
        if (baselineSteps < 0 || currentSteps <= baselineSteps) return Result.success()

        val offlineDistanceM = (currentSteps - baselineSteps) * STRIDE_M + remainderM
        val earned = floor(offlineDistanceM / attackDistanceM).toInt()
        if (currentBalance + earned < capacity) return Result.success()
        if (prefs.getBoolean(KEY_NOTIFIED_FULL, false)) return Result.success()

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
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("\uacf5\uaca9 \uae30\ud68c \ucda9\uc804 \uc644\ub8cc")
            .setContentText("\uc624\ud504\ub77c\uc778 \uacf5\uaca9 \uae30\ud68c\uac00 ${capacity}\ud68c \uac00\ub4dd \ucc3c\uc2b5\ub2c8\ub2e4.")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            applicationContext.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            NotificationManagerCompat.from(applicationContext).notify(NOTIFICATION_ID, notification)
            prefs.edit().putBoolean(KEY_NOTIFIED_FULL, true).apply()
        }
        return Result.success()
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
        const val KEY_CURRENT_BALANCE = "current_balance"
        const val KEY_CAPACITY = "capacity"
        const val KEY_ATTACK_DISTANCE_M = "offline_attack_distance_m"
        const val KEY_REMAINDER_M = "attack_distance_remainder_m"
        const val KEY_NOTIFIED_FULL = "notified_full"
        private const val FLUTTER_LAST_SENSOR_STEPS = "flutter.step_tracking.last_sensor_count"
        private const val STRIDE_M = 0.75
        private const val CHANNEL_ID = "offline_attack_full"
        private const val NOTIFICATION_ID = 1010
        private const val WORK_NAME = "offline_attack_capacity_check"

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
