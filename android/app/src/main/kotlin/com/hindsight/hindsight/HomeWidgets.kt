package com.hindsight.hindsight

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import kotlin.math.max

/**
 * Home-screen widgets.
 *
 * The cards themselves are drawn in Dart (`lib/widgets/hindsight_widgets.dart`,
 * rasterised by `widget_png.dart`). A RemoteViews layout is inflated inside the
 * launcher's own process, where the app's `@font` resources fall back to the
 * system face — so text laid out here could never be Bricolage Grotesque. The
 * app renders each widget to a PNG; these providers only show that file and
 * handle the tap.
 */
object WidgetStore {
    private const val PREFS = "hindsight_widgets"
    private const val KEY_IMAGES = "images"
    private const val KEY_SNAPSHOT = "snapshot"

    val providers = listOf(
        "ring" to RingWidget::class.java,
        "verdict" to VerdictWidget::class.java,
        "today" to TodayWidget::class.java,
        "limit" to LimitWidget::class.java,
        "week" to WeekWidget::class.java
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveImages(context: Context, json: String) {
        prefs(context).edit().putString(KEY_IMAGES, json).apply()
    }

    /** The numbers behind the widgets; the evening reminder still reads them. */
    fun saveSnapshot(context: Context, json: String) {
        prefs(context).edit().putString(KEY_SNAPSHOT, json).apply()
    }

    fun snapshot(context: Context): JSONObject? {
        val raw = prefs(context).getString(KEY_SNAPSHOT, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    fun imagePath(context: Context, key: String): String? {
        val raw = prefs(context).getString(KEY_IMAGES, null) ?: return null
        return try {
            JSONObject(raw).optString(key).takeIf { it.isNotBlank() }
        } catch (e: Exception) {
            null
        }
    }

    /** The box each placed widget occupies, in dp, so Dart can draw to fit. */
    fun sizes(context: Context): Map<String, FloatArray> {
        val manager = AppWidgetManager.getInstance(context)
        val out = mutableMapOf<String, FloatArray>()
        for ((key, provider) in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            var width = 0
            var height = 0
            for (id in ids) {
                val options = manager.getAppWidgetOptions(id)
                width = max(
                    width,
                    options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
                )
                height = max(
                    height,
                    options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
                )
            }
            if (width > 0 && height > 0) {
                out[key] = floatArrayOf(width.toFloat(), height.toFloat())
            }
        }
        return out
    }

    /** Re-renders every widget the user has placed on their home screen. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for ((_, provider) in providers) {
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

abstract class BaseWidget : AppWidgetProvider() {
    abstract val layoutId: Int
    abstract val imageKey: String

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)
            mountStoredImage(context, views)
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

    private fun mountStoredImage(context: Context, views: RemoteViews) {
        val path = WidgetStore.imagePath(context, imageKey) ?: return
        if (!File(path).exists()) return
        val bitmap = BitmapFactory.decodeFile(path) ?: return
        views.setImageViewBitmap(R.id.widget_image, bitmap)
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
    override val imageKey = "ring"
}

class VerdictWidget : BaseWidget() {
    override val layoutId = R.layout.widget_verdict
    override val imageKey = "verdict"
}

class LimitWidget : BaseWidget() {
    override val layoutId = R.layout.widget_limit
    override val imageKey = "limit"
}

class TodayWidget : BaseWidget() {
    override val layoutId = R.layout.widget_today
    override val imageKey = "today"
}

class WeekWidget : BaseWidget() {
    override val layoutId = R.layout.widget_week
    override val imageKey = "week"
}

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
