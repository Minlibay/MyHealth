package com.myhealth.myhealth

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Домашний виджет со скорами Здоровье / Сон / Восстановление.
 * Данные кладёт Flutter через пакет home_widget (SharedPreferences).
 */
class ScoreWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.score_widget)
            views.setTextViewText(R.id.widget_health, data.getString("health", "—"))
            views.setTextViewText(R.id.widget_sleep, data.getString("sleep", "—"))
            views.setTextViewText(R.id.widget_recovery, data.getString("recovery", "—"))

            // Тап по виджету открывает приложение.
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(
                        context, 0, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
