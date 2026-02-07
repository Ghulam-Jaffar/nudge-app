package com.sharedreminder.shared_reminder_app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class NudgeWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return NudgeWidgetItemFactory(applicationContext)
    }
}

class NudgeWidgetItemFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<WidgetItem> = emptyList()
    private var primaryColor: Int = Color.parseColor("#FF6B9D")
    private var textColor: Int = Color.parseColor("#212121")
    private var textSecondaryColor: Int = Color.parseColor("#757575")

    data class WidgetItem(
        val title: String,
        val isCompleted: Boolean,
        val remindAt: String?,
        val priority: String,
        val isOverdue: Boolean
    )

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        // Read theme
        primaryColor = prefs.getLong("theme_primary", 0xFFFF6B9D).toInt()
        textColor = prefs.getLong("theme_text", 0xFF212121.toInt().toLong()).toInt()
        textSecondaryColor = prefs.getLong("theme_text_secondary", 0xFF757575.toInt().toLong()).toInt()

        // Read items
        val itemsJson = prefs.getString("items_json", "[]") ?: "[]"
        val jsonArray = try {
            JSONArray(itemsJson)
        } catch (e: Exception) {
            JSONArray()
        }

        val newItems = mutableListOf<WidgetItem>()
        for (i in 0 until jsonArray.length()) {
            val obj = jsonArray.getJSONObject(i)
            newItems.add(
                WidgetItem(
                    title = obj.optString("title", ""),
                    isCompleted = obj.optBoolean("isCompleted", false),
                    remindAt = obj.optString("remindAt", null),
                    priority = obj.optString("priority", "none"),
                    isOverdue = obj.optBoolean("isOverdue", false)
                )
            )
        }
        items = newItems
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.nudge_widget_item)
        if (position >= items.size) return views

        val item = items[position]

        // Title
        views.setTextViewText(R.id.item_title, item.title)
        views.setTextColor(R.id.item_title, textColor)

        // Strikethrough + dim for completed items
        if (item.isCompleted) {
            views.setInt(R.id.item_title, "setPaintFlags",
                android.graphics.Paint.STRIKE_THRU_TEXT_FLAG or android.graphics.Paint.ANTI_ALIAS_FLAG)
            views.setTextColor(R.id.item_title, textSecondaryColor)
            views.setImageViewResource(R.id.item_check, R.drawable.ic_widget_check)
        } else {
            views.setInt(R.id.item_title, "setPaintFlags", android.graphics.Paint.ANTI_ALIAS_FLAG)

            // Priority color for the circle
            val circleColor = when (item.priority) {
                "high" -> Color.parseColor("#EF4444")
                "medium" -> Color.parseColor("#F59E0B")
                "low" -> Color.parseColor("#3B82F6")
                else -> primaryColor
            }
            views.setImageViewResource(R.id.item_check, R.drawable.ic_widget_circle)
            views.setInt(R.id.item_check, "setColorFilter", circleColor)
        }

        // Overdue styling
        if (item.isOverdue) {
            views.setTextColor(R.id.item_title, Color.parseColor("#EF4444"))
        }

        // Time badge
        if (item.remindAt != null && item.remindAt != "null" && item.remindAt.isNotEmpty()) {
            try {
                val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())
                sdf.timeZone = TimeZone.getDefault()
                val date = sdf.parse(item.remindAt)
                if (date != null) {
                    val timeFmt = SimpleDateFormat("h:mm a", Locale.getDefault())
                    views.setTextViewText(R.id.item_time, timeFmt.format(date))
                    views.setTextColor(R.id.item_time,
                        if (item.isOverdue) Color.parseColor("#EF4444") else textSecondaryColor)
                    views.setViewVisibility(R.id.item_time, View.VISIBLE)
                }
            } catch (e: Exception) {
                views.setViewVisibility(R.id.item_time, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.item_time, View.GONE)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
    override fun onDestroy() {}
}
