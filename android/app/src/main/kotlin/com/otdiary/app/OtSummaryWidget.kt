package com.otdiary.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class OtSummaryWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, manager, id)
    }
    companion object {
        private const val PREFS = "ot_diary_widget"
        fun store(context: Context, month: String, hours: String, days: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("month", month).putString("hours", hours).putString("days", days).apply()
            refresh(context)
        }
        fun clear(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
            refresh(context)
        }
        private fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, OtSummaryWidget::class.java))
            for (id in ids) render(context, manager, id)
        }
        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val month = SimpleDateFormat("yyyy-MM", Locale.US).format(Date())
            val fresh = prefs.getString("month", "") == month
            val views = RemoteViews(context.packageName, R.layout.ot_summary_widget)
            views.setTextViewText(R.id.widget_month, month)
            views.setTextViewText(R.id.widget_summary, if (fresh) "${prefs.getString("hours", "0")} ঘণ্টা • ${prefs.getString("days", "0")} দিন" else "অ্যাপ খুলে আপডেট করুন")
            val intent = Intent(context, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }
            views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            manager.updateAppWidget(id, views)
        }
    }
}
