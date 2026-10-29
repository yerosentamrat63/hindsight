package com.hindsight.hindsight

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Home-screen widgets.
 *
 * Dart cannot run inside a widget, so the app writes a JSON snapshot of today's
 * numbers and asks these providers to redraw. Charts are drawn to bitmaps here
 * because RemoteViews cannot animate an arc or stack weighted bars.
 */
object WidgetStore {
    private const val PREFS = "hindsight_widgets"
    private const val KEY = "snapshot"

    fun save(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, json)
            .apply()
    }

    fun snapshot(context: Context): JSONObject? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    /** Re-renders every widget the user has placed on their home screen. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val providers = listOf(
            RingWidget::class.java,
            VerdictWidget::class.java,
            LimitWidget::class.java,
            TodayWidget::class.java,
            WeekWidget::class.java
        )
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isEmpty()) continue
            val intent = Intent(context, provider).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}

// ------------------------------------------------------------------- palette

private val ORANGE = Color.parseColor("#FF6B3D")
private val INK = Color.parseColor("#F3EFE6")
private val MUTED = Color.parseColor("#A8A398")
private val NEUTRAL = Color.parseColor("#7D7A70")
private val LIME = Color.parseColor("#B7F34D")
private val TRACK = Color.parseColor("#232321")

// ------------------------------------------------------------------- helpers

/** "4h 33m", "52m", "2h" — same shape as the app's `dur()`. */
internal fun dur(minutes: Int): String {
    val m = max(0, minutes)
    val h = m / 60
    val r = m % 60
    return when {
        h == 0 -> "${r}m"
        r == 0 -> "${h}h"
        else -> "${h}h ${r}m"
    }
}

private fun tagColor(tag: String): Int = when (tag) {
    "wasted" -> ORANGE
    "productive" -> LIME
    else -> MUTED
}

private fun roundRect(width: Int, height: Int, radius: Float, color: Int): Bitmap {
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    canvas.drawRoundRect(
        RectF(0f, 0f, width.toFloat(), height.toFloat()),
        radius,
        radius,
        Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
    )
    return bitmap
}

/** Ring gauge: wasted time around the daily limit, with the cream pip on top. */
private fun ringBitmap(wasted: Int, limit: Int): Bitmap {
    val size = 240
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val stroke = 26f
    val inset = stroke / 2f + 6f
    val rect = RectF(inset, inset, size - inset, size - inset)

    canvas.drawOval(
        rect,
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            color = TRACK
        }
    )

    val ratio = if (limit <= 0) 1f else (wasted.toFloat() / limit).coerceIn(0f, 1f)
    if (ratio > 0f) {
        canvas.drawArc(
            rect,
            -90f,
            360f * ratio,
            false,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
                color = ORANGE
            }
        )
    }

    canvas.drawCircle(
        size / 2f,
        inset,
        9f,
        Paint(Paint.ANTI_ALIAS_FLAG).apply { color = INK }
    )
    return bitmap
}

/** Wasted / neutral / productive split bar. */
private fun splitBitmap(wasted: Int, neutral: Int, productive: Int): Bitmap {
    val width = 600
    val height = 16
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val total = wasted + neutral + productive
    val radius = height / 2f

    canvas.drawRoundRect(
        RectF(0f, 0f, width.toFloat(), height.toFloat()),
        radius, radius,
        paint.apply { color = TRACK }
    )
    if (total <= 0) return bitmap

    canvas.save()
    val clip = android.graphics.Path().apply {
        addRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius,
            android.graphics.Path.Direction.CW)
    }
    canvas.clipPath(clip)
    var x = 0f
    for ((minutes, color) in listOf(
        wasted to ORANGE,
        neutral to NEUTRAL,
        productive to LIME
    )) {
        if (minutes <= 0) continue
        val w = width * (minutes.toFloat() / total)
        canvas.drawRect(x, 0f, x + w, height.toFloat(), paint.apply { this.color = color })
        x += w
    }
    canvas.restore()
    return bitmap
}

/**
 * Wasted against the limit. The bar fills to the wasted share of the larger of
 * wasted/limit, and the cream marker sits where the limit falls, so going over
 * pushes the marker left of the end.
 */
private fun limitBarBitmap(wasted: Int, limit: Int): Bitmap {
    val width = 600
    val height = 40
    val barTop = 14f
    val barHeight = 12f
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val radius = barHeight / 2f

    canvas.drawRoundRect(
        RectF(0f, barTop, width.toFloat(), barTop + barHeight),
        radius, radius,
        paint.apply { color = TRACK }
    )

    val scale = max(max(limit, wasted), 1).toFloat()
    val fill = width * (wasted / scale)
    if (fill > 0f) {
        canvas.drawRoundRect(
            RectF(0f, barTop, fill.toFloat(), barTop + barHeight),
            radius, radius,
            paint.apply { color = ORANGE }
        )
    }

    val marker = (width * (limit / scale)).coerceIn(2f, width - 2f)
    canvas.drawRoundRect(
        RectF(marker - 3f, barTop - 6f, marker + 3f, barTop + barHeight + 6f),
        3f, 3f,
        paint.apply { color = INK }
    )
    return bitmap
}

/** Seven bars, lime under the limit and orange over, with the limit dashed. */
private fun weekBitmap(days: JSONArray, limit: Int): Bitmap {
    val width = 600
    val height = 200
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val gap = 14f
    val count = max(1, days.length())
    val barWidth = (width - gap * (count - 1)) / count

    var peak = limit
    for (i in 0 until days.length()) {
        peak = max(peak, days.optJSONObject(i)?.optInt("wasted") ?: 0)
    }
    val scale = max(peak, 1).toFloat()
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    for (i in 0 until days.length()) {
        val wasted = days.optJSONObject(i)?.optInt("wasted") ?: 0
        val left = i * (barWidth + gap)
        val h = (height * (wasted / scale)).coerceAtLeast(if (wasted > 0) 4f else 0f)
        if (h <= 0f) continue
        val rect = RectF(left, height - h, left + barWidth, height.toFloat())
        canvas.drawRoundRect(rect, 10f, 10f, paint.apply {
            color = if (wasted > limit) ORANGE else LIME
        })
        // Square off the foot of the bar, as in the design.
        canvas.drawRect(
            RectF(left, height - 10f, left + barWidth, height.toFloat()),
            paint
        )
    }

    val lineY = height - (height * (limit / scale)).coerceIn(0f, height.toFloat())
    canvas.drawLine(
        0f, lineY, width.toFloat(), lineY,
        paint.apply {
            color = Color.argb(128, 243, 239, 230)
            strokeWidth = 2.5f
            pathEffect = DashPathEffect(floatArrayOf(9f, 9f), 0f)
        }
    )
    return bitmap
}

// ------------------------------------------------------------------ providers

abstract class BaseWidget : AppWidgetProvider() {
    abstract val layoutId: Int
    abstract fun bind(context: Context, views: RemoteViews, snap: JSONObject)

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val snap = WidgetStore.snapshot(context) ?: JSONObject()
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)
            bind(context, views, snap)
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
            manager.updateAppWidget(id, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        onUpdate(context, manager, intArrayOf(appWidgetId))
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

class RingWidget : BaseWidget() {
    override val layoutId = R.layout.widget_ring

    override fun bind(context: Context, views: RemoteViews, snap: JSONObject) {
        val wasted = snap.optInt("wastedToday")
        val limit = max(1, snap.optInt("limit", 240))
        val over = wasted - limit

        views.setTextViewText(R.id.ring_value, dur(wasted))
        views.setImageViewBitmap(R.id.ring_chart, ringBitmap(wasted, limit))
        views.setTextViewText(
            R.id.ring_footer,
            if (over > 0) "${dur(over)} over limit" else "${dur(-over)} under limit"
        )
        views.setTextColor(R.id.ring_footer, if (over > 0) ORANGE else LIME)
    }
}

class VerdictWidget : BaseWidget() {
    override val layoutId = R.layout.widget_verdict

    override fun bind(context: Context, views: RemoteViews, snap: JSONObject) {
        val line = snap.optString("verdict").ifBlank { "Your verdict is being written." }
        views.setTextViewText(R.id.verdict_text, line)
        views.setTextViewText(
            R.id.verdict_tone,
            snap.optString("tone", "Brutal roast")
        )
    }
}

class LimitWidget : BaseWidget() {
    override val layoutId = R.layout.widget_limit

    override fun bind(context: Context, views: RemoteViews, snap: JSONObject) {
        val wasted = snap.optInt("wastedToday")
        val limit = max(1, snap.optInt("limit", 240))
        val over = wasted - limit

        views.setTextViewText(R.id.limit_value, dur(wasted))
        views.setTextViewText(R.id.limit_caption, "wasted of ${dur(limit)} limit")
        views.setTextViewText(
            R.id.limit_delta,
            if (over > 0) "+${dur(over)} over" else "${dur(-over)} under"
        )
        views.setTextColor(R.id.limit_delta, if (over > 0) ORANGE else LIME)
        views.setImageViewBitmap(R.id.limit_bar, limitBarBitmap(wasted, limit))
    }
}

class TodayWidget : BaseWidget() {
    override val layoutId = R.layout.widget_today

    override fun bind(context: Context, views: RemoteViews, snap: JSONObject) {
        val total = snap.optInt("totalToday")
        val delta = snap.optInt("totalDeltaYesterday")
        val wasted = snap.optInt("wastedToday")
        val neutral = snap.optInt("neutralToday")
        val productive = snap.optInt("productiveToday")

        views.setTextViewText(R.id.today_total, dur(total))
        views.setTextViewText(
            R.id.today_delta,
            if (delta == 0) "same as yesterday"
            else "${if (delta > 0) "+" else "-"}${dur(abs(delta))} vs yesterday"
        )
        views.setTextColor(R.id.today_delta, if (delta > 0) ORANGE else LIME)

        views.setImageViewBitmap(R.id.today_split, splitBitmap(wasted, neutral, productive))
        views.setTextViewText(R.id.today_wasted, "Wasted ${dur(wasted)}")
        views.setTextViewText(R.id.today_neutral, "Neutral ${dur(neutral)}")
        views.setTextViewText(R.id.today_productive, "Productive ${dur(productive)}")

        val apps = snap.optJSONArray("apps") ?: JSONArray()
        val rows = intArrayOf(R.id.app_row_0, R.id.app_row_1, R.id.app_row_2)
        val badges = intArrayOf(R.id.app_badge_0, R.id.app_badge_1, R.id.app_badge_2)
        val names = intArrayOf(R.id.app_name_0, R.id.app_name_1, R.id.app_name_2)
        val times = intArrayOf(R.id.app_time_0, R.id.app_time_1, R.id.app_time_2)

        for (i in 0..2) {
            val app = apps.optJSONObject(i)
            if (app == null) {
                views.setViewVisibility(rows[i], android.view.View.INVISIBLE)
                continue
            }
            views.setViewVisibility(rows[i], android.view.View.VISIBLE)
            views.setTextViewText(badges[i], app.optString("mono", "?"))
            views.setTextViewText(names[i], app.optString("name"))
            views.setTextViewText(times[i], dur(app.optInt("minutes")))
            views.setTextColor(times[i], tagColor(app.optString("tag")))
        }
    }
}

class WeekWidget : BaseWidget() {
    override val layoutId = R.layout.widget_week

    override fun bind(context: Context, views: RemoteViews, snap: JSONObject) {
        val wasted = snap.optInt("wastedWeek")
        val delta = snap.optInt("weekDelta")
        val limit = max(1, snap.optInt("limit", 240))
        val days = snap.optJSONArray("days") ?: JSONArray()

        views.setTextViewText(R.id.week_span, snap.optString("weekSpan"))
        views.setTextViewText(R.id.week_total, dur(wasted))
        views.setTextViewText(
            R.id.week_delta,
            if (delta == 0) "same as last week" else "${dur(abs(delta))} ${if (delta > 0) "more" else "less"}"
        )
        views.setTextColor(R.id.week_delta, if (delta > 0) ORANGE else LIME)
        views.setImageViewBitmap(R.id.week_chart, weekBitmap(days, limit))

        val labels = intArrayOf(
            R.id.week_day_0, R.id.week_day_1, R.id.week_day_2, R.id.week_day_3,
            R.id.week_day_4, R.id.week_day_5, R.id.week_day_6
        )
        for (i in labels.indices) {
            val day = days.optJSONObject(i)
            if (day == null) {
                views.setViewVisibility(labels[i], android.view.View.INVISIBLE)
                continue
            }
            val isToday = day.optBoolean("today")
            views.setTextViewText(labels[i], day.optString("label"))
            views.setTextColor(labels[i], if (isToday) INK else MUTED)
        }

        views.setTextViewText(
            R.id.week_verdict,
            snap.optString("verdict").ifBlank { "Open Hindsight for today's verdict." }
        )
    }
}
