package com.hindsight.hindsight

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * Reads per-app screen time from Android's UsageStats and hands it to Dart.
 *
 * Everything happens on the device: the channel returns daily totals, the top
 * apps' names and today's hourly profile. Nothing is uploaded from here.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "hindsight/usage"

    /**
     * UsageStats walks 14 days of per-app stats and resolves a label for every
     * package it finds. That is a lot of PackageManager work; on the UI thread
     * it stalls the launch animation, so the query runs here and only the reply
     * hops back to the main thread.
     */
    private val io = Executors.newSingleThreadExecutor()

    /** Only touched from [io]; app labels never change while the app runs. */
    private val labelCache = HashMap<String, String>()

    @Volatile
    private var destroyed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(hasUsageAccess())
                    "openAccessSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("no_settings", e.message, null)
                        }
                    }
                    "queryUsage" -> {
                        val days = call.argument<Int>("days") ?: 14
                        io.execute {
                            try {
                                val usage = queryUsage(days)
                                runOnUiThread { if (!destroyed) result.success(usage) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    if (!destroyed) {
                                        result.error("query_failed", e.message, null)
                                    }
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // The launcher widgets cannot read Dart data, so the app pushes a
        // JSON snapshot here and the providers redraw from it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hindsight/widgets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val json = call.arguments as? String
                        if (json == null) {
                            result.error("bad_args", "expected a JSON snapshot", null)
                        } else {
                            // The numbers behind the widgets; the evening reminder reads them.
                            WidgetStore.saveSnapshot(this, json)
                            WidgetStore.refreshAll(this)
                            result.success(null)
                        }
                    }
                    "updateImages" -> {
                        val paths = call.arguments as? Map<*, *>
                        if (paths == null) {
                            result.error("bad_args", "expected a map of image paths", null)
                        } else {
                            val json = org.json.JSONObject()
                            paths.forEach { (key, value) ->
                                json.put(key.toString(), value.toString())
                            }
                            WidgetStore.saveImages(this, json.toString())
                            WidgetStore.refreshAll(this)
                            result.success(null)
                        }
                    }
                    "sizes" -> {
                        val json = org.json.JSONObject()
                        WidgetStore.sizes(this).forEach { (key, box) ->
                            json.put(
                                key,
                                org.json.JSONArray()
                                    .put(box[0].toDouble())
                                    .put(box[1].toDouble())
                            )
                        }
                        result.success(json.toString())
                    }
                    else -> result.notImplemented()
                }
            }

        // The 22:00 verdict notification: Dart sets the time, Android owns the
        // alarm so it still fires when the app is not running.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hindsight/reminders")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val at = call.argument<Int>("atMinutes") ?: (22 * 60)
                        ReminderStore.save(this, enabled, at)
                        ReminderScheduler.apply(this)
                        result.success(null)
                    }
                    "hasPermission" -> result.success(ReminderStore.hasPermission(this))
                    "requestPermission" -> {
                        ReminderNotifier.ensureChannel(this)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            !ReminderStore.hasPermission(this)
                        ) {
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_REQUEST
                            )
                        }
                        result.success(null)
                    }
                    "canScheduleExact" ->
                        result.success(ReminderScheduler.canScheduleExact(this))
                    "openExactSettings" -> {
                        ReminderScheduler.openExactSettings(this)
                        result.success(null)
                    }
                    "openSettings" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                    .setData(android.net.Uri.parse("package:$packageName"))
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("no_settings", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    override fun onDestroy() {
        destroyed = true
        io.shutdown()
        super.onDestroy()
    }

    private fun startOfDay(offsetDays: Int = 0): Long {
        val c = Calendar.getInstance()
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        if (offsetDays != 0) {
            c.add(Calendar.DAY_OF_YEAR, offsetDays)
        }
        return c.timeInMillis
    }

    private fun queryUsage(days: Int): Map<String, Any> {
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val todayStart = startOfDay(0)
        val tomorrowStart = startOfDay(1)

        val apps = LinkedHashMap<String, Any>()
        val daily = LinkedHashMap<String, Any>()
        val totals = HashMap<String, Int>()

        val span = max(days, 1)
        val rows = dailyRows(manager, span)

        for ((key, row) in rows) {
            daily[key] = row
            row.forEach { (pkg, minutes) ->
                totals[pkg] = (totals[pkg] ?: 0) + minutes
            }
        }

        // Only the apps that mattered, biggest first, so the payload stays small.
        val ranked = totals.entries
            .sortedByDescending { it.value }
            .take(28)
        val labels = HashMap<String, String>()
        for (entry in ranked) {
            val pkg = entry.key
            val label = appLabel(pkg)
            // A launcher can slip in through a differently-named package even
            // when its id looks ordinary, so check the visible label too.
            if (isSystemNoise(pkg, label)) continue
            labels[pkg] = label
            val initials = initialOf(label)
            apps[pkg] = mapOf("name" to label, "initials" to initials)
        }

        val opens = LinkedHashMap<String, Int>()
        val hourly = LinkedHashMap<String, List<Int>>()
        readToday(manager, todayStart, tomorrowStart, labels, opens, hourly)

        return mapOf(
            "apps" to apps,
            "daily" to daily,
            "opens" to opens,
            "hourly" to hourly
        )
    }

    /**
     * Per-day foreground minutes in one pass. UsageStats daily buckets end at
     * midnight, so `lastTimeStamp - 1` keeps each row on the day it covers.
     * Some OEM builds ignore the interval and collapse the range into a single
     * bucket; those fall back to one query per day.
     */
    private fun dailyRows(
        manager: UsageStatsManager,
        span: Int
    ): LinkedHashMap<String, LinkedHashMap<String, Int>> {
        val begin = startOfDay(-(span - 1))
        val end = startOfDay(1)
        val rows = LinkedHashMap<String, LinkedHashMap<String, Int>>()

        val stats = manager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            begin,
            end
        ) ?: emptyList()

        for (stat in stats) {
            val pkg = stat.packageName ?: continue
            // Filter by id only here: resolving a label for every package of
            // every day was the slow part of the old query.
            if (isNoiseId(pkg)) continue
            val minutes = (stat.totalTimeInForeground / 60000L).toInt()
            if (minutes <= 0) continue
            val stamp = stat.lastTimeStamp - 1
            if (stamp < begin) continue
            val row = rows.getOrPut(dayKey(stamp)) { LinkedHashMap() }
            row[pkg] = (row[pkg] ?: 0) + minutes
        }

        if (rows.size <= 1 && span > 1) {
            rows.clear()
            for (offset in span - 1 downTo 0) {
                val dayStart = startOfDay(-offset)
                val dayEnd = startOfDay(-offset + 1)
                val row = LinkedHashMap<String, Int>()
                val dayStats = manager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    dayStart,
                    dayEnd
                ) ?: continue
                for (stat in dayStats) {
                    val pkg = stat.packageName ?: continue
                    if (isNoiseId(pkg)) continue
                    val minutes = (stat.totalTimeInForeground / 60000L).toInt()
                    if (minutes <= 0) continue
                    row[pkg] = (row[pkg] ?: 0) + minutes
                }
                if (row.isNotEmpty()) rows[dayKey(dayStart)] = row
            }
        }

        return rows
    }

    /** Counts opens and foreground minutes per hour for today. */
    private fun readToday(
        manager: UsageStatsManager,
        start: Long,
        end: Long,
        labels: Map<String, String>,
        opens: MutableMap<String, Int>,
        hourly: MutableMap<String, List<Int>>
    ) {
        val buckets = HashMap<String, IntArray>()
        val resumedAt = HashMap<String, Long>()
        val events = manager.queryEvents(start, end)
        val event = UsageEvents.Event()

        fun bucketFor(pkg: String): IntArray =
            buckets.getOrPut(pkg) { IntArray(24) }

        fun addMinutes(pkg: String, from: Long, to: Long) {
            var cursor = from
            while (cursor < to) {
                val hour = hourOf(cursor)
                val nextHour = startOfHour(cursor) + HOUR_MS
                val slice = minOf(to, nextHour) - cursor
                bucketFor(pkg)[hour] += (slice / 60000L).toInt()
                cursor += slice
            }
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (!labels.containsKey(pkg)) continue
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    resumedAt[pkg] = event.timeStamp
                    opens[pkg] = (opens[pkg] ?: 0) + 1
                }
                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val from = resumedAt.remove(pkg) ?: continue
                    if (event.timeStamp > from) addMinutes(pkg, from, event.timeStamp)
                }
            }
        }

        // Anything still in the foreground counts up to now.
        val now = minOf(System.currentTimeMillis(), end)
        resumedAt.forEach { (pkg, from) ->
            if (now > from) addMinutes(pkg, from, now)
        }

        buckets.forEach { (pkg, mins) ->
            hourly[pkg] = mins.toList()
        }
    }

    /** Noise that is identifiable from the package id alone (no label lookup). */
    private fun isNoiseId(pkg: String): Boolean {
        if (pkg == packageName || pkg == "android") return true
        val id = pkg.lowercase()
        return id.contains("launcher") ||
            id.contains("systemui") ||
            id.contains("system.ui") ||
            id.contains("setupwizard") ||
            id.contains("permissioncontroller") ||
            id.contains("packageinstaller") ||
            id.equals("com.android.settings") ||
            id.endsWith(".settings")
    }

    /**
     * Launchers, the system UI, permission dialogs and Hindsight itself are not
     * "screen time": showing "One UI Home A� 2h" tells the user nothing and
     * pollutes the wasted total.
     */
    private fun isSystemNoise(pkg: String, label: String? = null): Boolean {
        if (isNoiseId(pkg)) return true
        val name = (label ?: appLabel(pkg)).lowercase().trim()
        return name == "one ui home" ||
            name == "system ui" ||
            name == "launcher" ||
            name == "home" ||
            name == "settings" ||
            name == "pixel launcher" ||
            name == "samsung experience home"
    }

    private fun appLabel(pkg: String): String {
        // isSystemNoise asks for the label of every stat of every day, so the
        // same handful of packages used to be resolved 14 times over.
        labelCache[pkg]?.let { return it }
        val label = try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            pkg.substringAfterLast('.').replaceFirstChar { it.uppercase() }
        }
        labelCache[pkg] = label
        return label
    }

    private fun initialOf(label: String): String {
        val words = label.trim().split(' ').filter { it.isNotEmpty() }
        if (words.isEmpty()) return "?"
        if (words.size == 1) {
            return words[0].take(2).replaceFirstChar { it.uppercase() }
        }
        return (words[0].take(1) + words[1].take(1)).uppercase()
    }

    private fun dayKey(millis: Long): String {
        val c = Calendar.getInstance()
        c.timeInMillis = millis
        val y = c.get(Calendar.YEAR)
        val m = c.get(Calendar.MONTH) + 1
        val d = c.get(Calendar.DAY_OF_MONTH)
        return String.format("%04d%02d%02d", y, m, d)
    }

    private fun hourOf(millis: Long): Int {
        val c = Calendar.getInstance()
        c.timeInMillis = millis
        return c.get(Calendar.HOUR_OF_DAY)
    }

    private fun startOfHour(millis: Long): Long {
        val c = Calendar.getInstance()
        c.timeInMillis = millis
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    companion object {
        private const val HOUR_MS = 60L * 60L * 1000L
        private const val NOTIFICATION_REQUEST = 4141
    }
}
