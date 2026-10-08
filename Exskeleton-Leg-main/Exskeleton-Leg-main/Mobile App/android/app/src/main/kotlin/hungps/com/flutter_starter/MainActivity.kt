package com.flutter.nextai

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val LOCAL_NOTIFICATION_CHANNEL = "exo_leg/local_notifications"
        const val CHANNEL_ID = "exo_leg_alerts"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ExoNativeBle(this, flutterEngine.dartExecutor.binaryMessenger)
        createNotificationChannel()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCAL_NOTIFICATION_CHANNEL,
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method != "show") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            showLocalNotification(call, result)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Exoskeleton alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Thông báo cảnh báo và trạng thái Exoskeleton Leg"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun showLocalNotification(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title") ?: "Exoskeleton Leg"
        val body = call.argument<String>("body") ?: ""
        val id = call.argument<Int>("id") ?: (System.currentTimeMillis() and 0x7fffffff).toInt()
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = intent?.let {
            PendingIntent.getActivity(
                this,
                id,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        if (pendingIntent != null) builder.setContentIntent(pendingIntent)
        try {
            NotificationManagerCompat.from(this).notify(id, builder.build())
            result.success(null)
        } catch (security: SecurityException) {
            result.error("permission", "POST_NOTIFICATIONS permission is not granted", null)
        }
    }
}
