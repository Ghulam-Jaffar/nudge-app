package com.sharedreminder.shared_reminder_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class NudgeWidgetProviderSimple : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val COLOR_TITLE = 0xFF1A1A1A.toInt()
        private const val COLOR_SUBTITLE = 0xFF757575.toInt()
        private const val COLOR_ITEM = 0xFF333333.toInt()
        private const val COLOR_DONE = 0xFFA0A0A0.toInt()
        private const val COLOR_OVERDUE = 0xFFE53935.toInt()
        private const val COLOR_TIME = 0xFF888888.toInt()
        private const val COLOR_EMPTY = 0xFF999999.toInt()
        private const val COLOR_DIVIDER = 0x22000000.toInt()
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (_: Exception) {
                val views = RemoteViews(context.packageName, R.layout.nudge_widget_simple)
                views.setTextViewText(R.id.widget_text, "Nudge\nTap to open")
                setClickIntent(context, views)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "es.antonborri.home_widget.action.UPDATE") {
            val mgr = AppWidgetManager.getInstance(context)
            val cn = ComponentName(context, NudgeWidgetProviderSimple::class.java)
            val ids = mgr.getAppWidgetIds(cn)
            if (ids.isNotEmpty()) {
                onUpdate(context, mgr, ids)
            }
        }
    }

    private fun setClickIntent(context: Context, views: RemoteViews) {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pi = PendingIntent.getActivity(
                context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pi)
        }
    }

    private fun formatTime(isoString: String?): String? {
        if (isoString == null) return null
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = sdf.parse(isoString) ?: return null
            val timeFmt = SimpleDateFormat("h:mm a", Locale.getDefault())
            timeFmt.format(date)
        } catch (_: Exception) { null }
    }

    private fun updateWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.nudge_widget_simple)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Check signed-in state
        val signedIn = try { prefs.getBoolean("signed_in", false) } catch (_: Exception) { false }

        val ssb = SpannableStringBuilder()

        if (!signedIn) {
            // ── Signed-out state ──
            appendStyled(ssb, "Nudge", COLOR_TITLE, 16, bold = true)
            ssb.append("\n\n")
            appendStyled(ssb, "Sign in to see your\nreminders here", COLOR_EMPTY, 13)
            views.setTextViewText(R.id.widget_text, ssb)
            setClickIntent(context, views)
            mgr.updateAppWidget(widgetId, views)
            return
        }

        // ── Signed-in state ──
        val json = prefs.getString("items_json", null)
        val items = if (json != null) {
            try { JSONArray(json) } catch (_: Exception) { JSONArray() }
        } else { JSONArray() }

        val total = items.length()
        val count = total.coerceAtMost(5)

        // Header: "Nudge · Today"
        appendStyled(ssb, "Nudge", COLOR_TITLE, 15, bold = true)
        appendStyled(ssb, "  ·  ", COLOR_SUBTITLE, 13)

        val incomplete = if (total > 0) {
            (0 until total).count { !items.getJSONObject(it).optBoolean("isCompleted", false) }
        } else 0

        if (total > 0 && incomplete == 0) {
            appendStyled(ssb, "All done! ✨", COLOR_SUBTITLE, 13)
        } else if (incomplete > 0) {
            appendStyled(ssb, "$incomplete left today", COLOR_SUBTITLE, 13)
        } else {
            val dateFmt = SimpleDateFormat("EEE, MMM d", Locale.getDefault())
            appendStyled(ssb, dateFmt.format(Date()), COLOR_SUBTITLE, 13)
        }

        // Thin divider
        ssb.append("\n")
        val divStart = ssb.length
        ssb.append("─────────────────────────")
        ssb.setSpan(ForegroundColorSpan(COLOR_DIVIDER), divStart, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        ssb.setSpan(AbsoluteSizeSpan(4, true), divStart, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

        // Items
        if (count > 0) {
            for (i in 0 until count) {
                val obj = items.getJSONObject(i)
                val title = obj.optString("title", "Reminder")
                val done = obj.optBoolean("isCompleted", false)
                val isOverdue = obj.optBoolean("isOverdue", false)
                val remindAtRaw = obj.optString("remindAt", "")
                val remindAt = if (remindAtRaw.isNullOrEmpty() || remindAtRaw == "null") null else remindAtRaw
                val time = formatTime(remindAt)

                ssb.append("\n")

                if (done) {
                    appendStyled(ssb, "✓  $title", COLOR_DONE, 13)
                } else {
                    val icon = if (isOverdue) "⚠  " else "○  "
                    val titleColor = if (isOverdue) COLOR_OVERDUE else COLOR_ITEM
                    appendStyled(ssb, icon, titleColor, 13)
                    appendStyled(ssb, title, titleColor, 13)
                    if (time != null) {
                        appendStyled(ssb, "  $time", COLOR_TIME, 11)
                    }
                }
            }
            if (total > 5) {
                ssb.append("\n")
                appendStyled(ssb, "+${total - 5} more", COLOR_SUBTITLE, 12)
            }
        } else {
            ssb.append("\n\n")
            appendStyled(ssb, "Nothing scheduled today\nTap to add a reminder", COLOR_EMPTY, 13)
        }

        views.setTextViewText(R.id.widget_text, ssb)
        setClickIntent(context, views)
        mgr.updateAppWidget(widgetId, views)
    }

    private fun appendStyled(
        ssb: SpannableStringBuilder,
        text: String,
        color: Int,
        sizeSp: Int,
        bold: Boolean = false
    ) {
        val start = ssb.length
        ssb.append(text)
        ssb.setSpan(ForegroundColorSpan(color), start, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        ssb.setSpan(AbsoluteSizeSpan(sizeSp, true), start, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (bold) {
            ssb.setSpan(StyleSpan(Typeface.BOLD), start, ssb.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }
}
