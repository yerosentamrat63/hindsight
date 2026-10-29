package com.hindsight.hindsight

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.util.Calendar

/**
 * The "notify me at 22:00" feature.
 *
 * Dart cannot wake a killed app, so the daily reminder is an AlarmManager
 * alarm: a receiver posts the notification from the last widget snapshot and
 * re-arms itself for the next evening. A boot receiver puts it back after a
 * restart. No server, no push.
 */
object ReminderStore {
    private const val PREFS = "hindsight_reminders"
    private const val ENABLED = "enabled"
    private const val AT = "atMinutes"

    fun enabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(ENABLED, false)

    fun atMinutes(context: Context): Int =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getInt(AT, 22 * 60)

    fun save(context: Context, enabled: Boolean, atMinutes: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ENABLED, enabled)
            .putInt(AT, atMinutes.coerceIn(0, 24 * 60 - 1))
            .apply()
    }

    /** Android 13+ needs runtime permission to post anything at all. */
    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
}

object ReminderScheduler {
    private const val REQUEST_CODE = 2200
    // Android batches inexact alarms and expands a shorter window to this
    // minimum, so without the exact-alarm grant 22:00 means 22:00-22:10.
    private const val WINDOW_MS = 10L * 60L * 1000L

    fun apply(context: Context) {
        if (ReminderStore.enabled(context)) schedule(context) else cancel(context)
    }

    fun schedule(context: Context) {
        val manager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pending(context)
        val next = nextTrigger(ReminderStore.atMinutes(context))

        // Exact alarms need a special grant on Android 12+; when it is missing
        // a ten-minute window is the honest alternative, not a crash.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !manager.canScheduleExactAlarms()
        ) {
            manager.setWindow(AlarmManager.RTC_WAKEUP, next, WINDOW_MS, pending)
        } else {
            manager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                next,
                pending
            )
        }
    }

    /** Exact alarms are a special grant on Android 12+. */
    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return manager.canScheduleExactAlarms()
    }

    /** The system screen where that grant lives. */
    fun openExactSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            val intent = Intent(
                android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                android.net.Uri.parse("package:${context.packageName}")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (_: Exception) {
            // Some OEMs hide this screen; the ten-minute window stays.
        }
    }

    fun cancel(context: Context) {
        val manager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pending(context)
        manager.cancel(pending)
        pending.cancel()
    }

    private fun pending(context: Context): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Today at [atMinutes], or tomorrow when that time has already passed. */
    fun nextTrigger(atMinutes: Int): Long {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, atMinutes / 60)
        calendar.set(Calendar.MINUTE, atMinutes % 60)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }
        return calendar.timeInMillis
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!ReminderStore.enabled(context)) return
        ReminderNotifier.post(context)
        // Alarms do not repeat themselves: arm tomorrow's before going quiet.
        ReminderScheduler.schedule(context)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            ReminderScheduler.apply(context)
        }
    }
}

/**
 * Android tells us when the "Alarms & reminders" grant changes. Re-arm then,
 * so the reminder moves from a ten-minute window to the exact minute without
 * needing the app to be opened.
 */
class ExactAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderScheduler.apply(context)
    }
}

object ReminderNotifier {
    private const val CHANNEL = "verdict"
    private const val NOTIFICATION_ID = 2200

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                "Daily verdict",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "One evening summary of what your screen time cost."
            }
        )
    }

    fun post(context: Context) {
        if (!ReminderStore.hasPermission(context)) return
        ensureChannel(context)

        val snap = WidgetStore.snapshot(context)
        val fresh = snap != null && isToday(snap.optLong("updated", 0L))
        val wasted = if (fresh) snap.optInt("wastedToday") else 0
        val limit = if (fresh) snap.optInt("limit", 240) else 240

        val title = when {
            !fresh -> "Today's verdict is ready"
            wasted <= 0 -> "Nothing wasted today. Suspicious."
            wasted > limit -> "${dur(wasted)} wasted — over your ${dur(limit)} limit"
            else -> "${dur(wasted)} wasted today"
        }
        val line = if (fresh) {
            snap.optString("verdict").ifBlank { "Open Hindsight for the verdict." }
        } else {
            "Open Hindsight for the verdict."
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(line)
            .setStyle(Notification.BigTextStyle().bigText(line))
            .setColor(0xFFFF6B3D.toInt())
            .setAutoCancel(true)
            .setContentIntent(openIntent(context))
            .build()

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun openIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** The snapshot is written while the app runs; an old one is not today's. */
    private fun isToday(millis: Long): Boolean {
        if (millis <= 0L) return false
        val then = Calendar.getInstance().apply { timeInMillis = millis }
        val now = Calendar.getInstance()
        return then.get(Calendar.YEAR) == now.get(Calendar.YEAR) &&
            then.get(Calendar.DAY_OF_YEAR) == now.get(Calendar.DAY_OF_YEAR)
    }
}
