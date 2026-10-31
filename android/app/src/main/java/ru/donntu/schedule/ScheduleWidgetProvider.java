package ru.donntu.schedule;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.RemoteViews;
import ru.donntu.schedule.flutter_lab.R;
import java.util.ArrayList;
import java.util.List;

public final class ScheduleWidgetProvider extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        for (int id : ids) update(context, manager, id);
    }

    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager manager, int id, Bundle options) {
        update(context, manager, id);
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        ScheduleRuntime.refresh(context);
    }

    public static void refresh(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        for (int id : manager.getAppWidgetIds(new ComponentName(context, ScheduleWidgetProvider.class))) update(context, manager, id);
    }

    private static int rowsFor(AppWidgetManager manager, int id) {
        int height = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160);
        return Math.max(1, Math.min(6, (height - 48) / 96));
    }

    private static void update(Context context, AppWidgetManager manager, int id) {
        ScheduleSnapshot data = ScheduleRuntime.read(context);
        long now = System.currentTimeMillis();
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.schedule_widget);
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, 1, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
        views.setTextViewText(R.id.widget_group, data.group);
        views.removeAllViews(R.id.widget_list);
        views.setViewVisibility(R.id.widget_message, View.GONE);
        if (!data.fresh(now)) {
            message(views, "Обновите расписание", "Откройте приложение — сохранённые данные устарели");
        } else {
            List<ScheduleSnapshot.Lesson> day = data.day(now);
            ScheduleSnapshot.Lesson current = data.current(now), next = data.next(now);
            int rows = rowsFor(manager, id);
            int from = 0;
            for (int i = 0; i < day.size(); i++) {
                if (day.get(i) == current || (current == null && day.get(i) == next)) {
                    from = i;
                    break;
                }
            }
            List<ScheduleSnapshot.Lesson> shown = new ArrayList<>();
            if (current == null && next == null && !day.isEmpty()) {
                message(views, "Занятия закончились", "");
            } else {
                for (int i = from; i < day.size() && shown.size() < rows; i++) shown.add(day.get(i));
                if (day.isEmpty()) message(views, "Сегодня занятий нет", "");
            }
            for (ScheduleSnapshot.Lesson lesson : shown) {
                boolean isCurrent = lesson == current;
                boolean isNext = current == null && lesson == next;
                views.addView(R.id.widget_list, card(context, lesson, isCurrent, isNext, now));
            }
        }
        manager.updateAppWidget(id, views);
    }

    private static void message(RemoteViews views, String title, String text) {
        views.setViewVisibility(R.id.widget_message, View.VISIBLE);
        views.setTextViewText(R.id.widget_message_title, title);
        views.setTextViewText(R.id.widget_message_text, text);
        views.setViewVisibility(R.id.widget_message_text, text.isEmpty() ? View.GONE : View.VISIBLE);
    }

    private static RemoteViews card(Context context, ScheduleSnapshot.Lesson lesson, boolean current, boolean next, long now) {
        RemoteViews card = new RemoteViews(context.getPackageName(), R.layout.schedule_widget_card);
        card.setInt(R.id.card_root, "setBackgroundResource", current ? R.drawable.widget_card_current : R.drawable.widget_card);
        if (current || next) {
            card.setViewVisibility(R.id.card_tag, View.VISIBLE);
            card.setTextViewText(R.id.card_tag, current ? "Сейчас · до " + ScheduleSnapshot.clock(lesson.end) : "Следующая пара · " + ScheduleSnapshot.nextLabel(now, lesson.start));
        } else {
            card.setViewVisibility(R.id.card_tag, View.GONE);
        }
        card.setTextViewText(R.id.card_start, ScheduleSnapshot.time(lesson.start));
        card.setTextViewText(R.id.card_end, ScheduleSnapshot.time(lesson.end));
        card.setTextViewText(R.id.card_subject, lesson.subject);
        card.setTextViewText(R.id.card_meta, lesson.kind + " · " + lesson.rooms);
        card.setViewVisibility(R.id.card_teacher, lesson.teacher.isEmpty() ? View.GONE : View.VISIBLE);
        card.setTextViewText(R.id.card_teacher, lesson.teacher);
        card.setViewVisibility(R.id.card_change, lesson.change.isEmpty() ? View.GONE : View.VISIBLE);
        card.setTextViewText(R.id.card_change, lesson.change);
        return card;
    }
}
