package com.sharedreminder.shared_reminder_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.app.PendingIntent
import org.json.JSONArray

class NudgeWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Handle home_widget updates
        if (intent.action == "es.antonborri.home_widget.action.UPDATE") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, NudgeWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.nudge_widget_layout)

        // Read theme colors
        val primaryColor = prefs.getLong("theme_primary", 0xFFFF6B9D).toInt()
        val bgColor = prefs.getLong("theme_background", 0xFFFFFFFF).toInt()
        val cardColor = prefs.getLong("theme_card", 0xFFFFFFFF).toInt()
        val textColor = prefs.getLong("theme_text", 0xFF212121.toInt().toLong()).toInt()
        val textSecondaryColor = prefs.getLong("theme_text_secondary", 0xFF757575.toInt().toLong()).toInt()
        val isDark = prefs.getBoolean("is_dark", false)

        // Apply theme to header
        views.setTextColor(R.id.widget_title, textColor)
        views.setTextColor(R.id.widget_count, textSecondaryColor)
        views.setTextColor(R.id.widget_empty_text, textSecondaryColor)
        views.setInt(R.id.widget_logo, "setColorFilter", primaryColor)
        views.setInt(R.id.widget_add_button, "setColorFilter", primaryColor)

        // Divider color
        val dividerColor = if (isDark) Color.argb(30, 255, 255, 255) else Color.argb(26, 0, 0, 0)
        views.setInt(R.id.widget_divider, "setBackgroundColor", dividerColor)

        // Read items
        val itemsJson = prefs.getString("items_json", "[]") ?: "[]"
        val incompleteCount = prefs.getLong("incomplete_count", 0).toInt()

        val items = try {
            JSONArray(itemsJson)
        } catch (e: Exception) {
            JSONArray()
        }

        // Update count badge
        if (incompleteCount > 0) {
            views.setTextViewText(R.id.widget_count, "$incompleteCount left")
            views.setViewVisibility(R.id.widget_count, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_count, View.GONE)
        }

        // Show/hide empty state vs list
        if (items.length() == 0) {
            views.setViewVisibility(R.id.widget_list, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_list, View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, View.GONE)

            // Set up RemoteViews adapter for the list
            val serviceIntent = Intent(context, NudgeWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
        }

        // Click on widget opens app
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
        }

        // Click on add button opens app (deep link to create)
        val addIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (addIntent != null) {
            addIntent.putExtra("action", "create_reminder")
            val addPendingIntent = PendingIntent.getActivity(
                context, 1, addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, addPendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
    }
}
