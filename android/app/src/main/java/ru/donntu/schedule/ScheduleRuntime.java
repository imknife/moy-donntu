package ru.donntu.schedule;

import android.Manifest;
import android.app.AlarmManager;
import android.app.KeyguardManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.PowerManager;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;
import org.json.JSONArray;
import org.json.JSONObject;
import ru.donntu.schedule.flutter_lab.R;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public final class ScheduleRuntime {
    private static final String TAG = "DonntuSchedule";
    private static final String STORE = "DonntuSchedule";
    private static final String LOUD_CHANNEL = "lesson_live2";
    private static final String QUIET_CHANNEL = "lesson_live3";
    private static final String REMIND_CHANNEL = "lesson_reminder";
    private static final String OLD_CHANNEL = "lesson_progress";
    private static final String OLD_CHANNEL_2 = "lesson_live";
    private static final int NOTICE = 3300;
    private static final int ALARM = 3301;
    private static final int STOP_REQUEST = 3302;
    private static final int REMIND = 3400;
    private static final long FALLBACK = 6 * 3_600_000L;
    public static final String MANUAL = "ru.donntu.schedule.MANUAL_REMINDER";
    public static final String STOP = "ru.donntu.schedule.STOP_PROGRESS";
    private static final String STOPPED_DAY = "ds_progress_stopped_day";
    private static final String REMINDED = "ds_reminded";
    private static final String MANUAL_STORE = "ds_manual";

    private ScheduleRuntime() { }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(STORE, Context.MODE_PRIVATE);
    }

    private static String today() {
        return LocalDate.now(ScheduleSnapshot.MOSCOW).toString();
    }

    public static boolean stoppedToday(Context context) {
        return today().equals(prefs(context).getString(STOPPED_DAY, ""));
    }

    public static void resume(Context context) {
        prefs(context).edit().remove(STOPPED_DAY).commit();
    }

    public static void save(Context context, String raw) {
        prefs(context).edit().putString("ds_widget", raw).commit();
    }

    public static ScheduleSnapshot read(Context context) {
        try {
            JSONObject data = new JSONObject(prefs(context).getString("ds_widget", ""));
            List<ScheduleSnapshot.Lesson> lessons = new ArrayList<>();
            List<LocalDate> dates = new ArrayList<>();
            JSONArray days = data.getJSONArray("days");
            for (int i = 0; i < Math.min(7, days.length()); i++) {
                JSONObject day = days.getJSONObject(i);
                String date = day.getString("date");
                dates.add(LocalDate.parse(date));
                JSONArray items = day.getJSONArray("lessons");
                for (int j = 0; j < Math.min(40, items.length()); j++) {
                    JSONObject l = items.getJSONObject(j);
                    int start = l.getInt("start"), end = l.getInt("end");
                    if (start < 0 || end <= start || end > 1440) continue;
                    ScheduleSnapshot.Lesson lesson = new ScheduleSnapshot.Lesson(ScheduleSnapshot.instant(date, start), ScheduleSnapshot.instant(date, end), l.getString("subject"), l.optString("kind"), l.optString("rooms"));
                    lesson.teacher = l.optString("teacher");
                    lesson.change = l.isNull("change") ? "" : l.optString("change", "");
                    lessons.add(lesson);
                }
            }
            return new ScheduleSnapshot(data.getString("group"), data.optBoolean("live"), data.optBoolean("persistent"), data.optInt("remind", 0), data.optLong("updatedAt"), lessons, dates);
        } catch (Exception ignored) {
            return new ScheduleSnapshot("Выберите группу", false, false, 0, 0, List.of(), List.of());
        }
    }

    private static boolean hidesOngoingOnLockscreen() {
        String maker = Build.MANUFACTURER.toLowerCase();
        return maker.contains("vivo") || maker.contains("iqoo");
    }

    private static String lessonChannel() {
        return hidesOngoingOnLockscreen() ? LOUD_CHANNEL : QUIET_CHANNEL;
    }

    public static boolean exactAlarms(Context context) {
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        return Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms();
    }

    static boolean mayNotify(Context context) {
        return Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
    }

    public static JSONObject status(Context context) {
        JSONObject out = new JSONObject();
        try {
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            boolean allowed = NotificationManagerCompat.from(context).areNotificationsEnabled();
            boolean channelOn = true;
            if (Build.VERSION.SDK_INT >= 26) {
                NotificationChannel channel = manager.getNotificationChannel(lessonChannel());
                channelOn = channel == null || channel.getImportance() != NotificationManager.IMPORTANCE_NONE;
            }
            boolean promoted = true;
            if (Build.VERSION.SDK_INT >= 36) promoted = manager.canPostPromotedNotifications();
            out.put("notifications", allowed && channelOn && mayNotify(context))
                .put("exactAlarms", exactAlarms(context))
                .put("promoted", promoted)
                .put("stoppedToday", stoppedToday(context))
                .put("manufacturer", Build.MANUFACTURER.toLowerCase())
                .put("sdk", Build.VERSION.SDK_INT);
        } catch (Exception ignored) { }
        return out;
    }

    private static BroadcastReceiver screenOn;

    static boolean screenLocked(Context context) {
        KeyguardManager keyguard = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
        PowerManager power = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        return (keyguard != null && keyguard.isKeyguardLocked()) || (power != null && !power.isInteractive());
    }

    private static boolean wouldWakeScreen(Context context) {
        PowerManager power = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        return !hidesOngoingOnLockscreen() && power != null && !power.isInteractive();
    }

    private static synchronized void watchScreen(Context context) {
        if (screenOn != null) return;
        screenOn = new BroadcastReceiver() {
            @Override
            public void onReceive(Context c, Intent intent) {
                ScheduleSnapshot data = read(c);
                if (Intent.ACTION_SCREEN_ON.equals(intent.getAction()) && hidesOngoingOnLockscreen() && data.live && screenLocked(c)) {
                    NotificationManagerCompat.from(c).cancel(NOTICE);
                }
                updateNotification(c, data, System.currentTimeMillis());
            }
        };
        IntentFilter filter = new IntentFilter(Intent.ACTION_SCREEN_ON);
        filter.addAction(Intent.ACTION_SCREEN_OFF);
        filter.addAction(Intent.ACTION_USER_PRESENT);
        ContextCompat.registerReceiver(context.getApplicationContext(), screenOn, filter, ContextCompat.RECEIVER_NOT_EXPORTED);
    }

    public static synchronized boolean refresh(Context context) {
        watchScreen(context);
        ScheduleSnapshot data = read(context);
        long now = System.currentTimeMillis();
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent alarm = PendingIntent.getBroadcast(context, ALARM, new Intent(context, ScheduleBoundaryReceiver.class), PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        manager.cancel(alarm);
        long next = data.nextBoundary(now);
        if (next <= now) next = now + FALLBACK;
        boolean exact = exactAlarms(context);
        if (next > now) {
            try {
                if (exact) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarm);
                else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarm);
            } catch (SecurityException denied) {
                exact = false;
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarm);
            }
        }
        restoreManual(context, now);
        updateNotification(context, data, now);
        remind(context, data, now);
        return exact;
    }

    public static boolean scheduleManual(Context context, int id, long at, String title, String body) {
        if (at <= System.currentTimeMillis()) {
            forgetManual(context, id);
            return false;
        }
        armManual(context, id, at, title, body);
        rememberManual(context, id, at, title, body);
        return true;
    }

    public static void cancelManual(Context context, int id) {
        ((AlarmManager) context.getSystemService(Context.ALARM_SERVICE)).cancel(manualIntent(context, id, "", ""));
        forgetManual(context, id);
    }

    private static void armManual(Context context, int id, long at, String title, String body) {
        AlarmManager manager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent alarm = manualIntent(context, id, title, body);
        try {
            if (exactAlarms(context)) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarm);
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarm);
        } catch (SecurityException denied) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarm);
        }
    }

    private static JSONObject manualEntries(Context context) {
        try {
            return new JSONObject(prefs(context).getString(MANUAL_STORE, "{}"));
        } catch (Exception broken) {
            return new JSONObject();
        }
    }

    private static synchronized void rememberManual(Context context, int id, long at, String title, String body) {
        try {
            JSONObject entries = manualEntries(context);
            entries.put(String.valueOf(id), new JSONObject().put("at", at).put("title", title).put("body", body));
            prefs(context).edit().putString(MANUAL_STORE, entries.toString()).commit();
        } catch (Exception error) {
            Log.w(TAG, "Не удалось сохранить напоминание", error);
        }
    }

    private static synchronized void forgetManual(Context context, int id) {
        JSONObject entries = manualEntries(context);
        if (entries.remove(String.valueOf(id)) != null) prefs(context).edit().putString(MANUAL_STORE, entries.toString()).commit();
    }

    private static synchronized void restoreManual(Context context, long now) {
        JSONObject entries = manualEntries(context);
        JSONArray keys = entries.names();
        if (keys == null) return;
        boolean changed = false;
        for (int i = 0; i < keys.length(); i++) {
            String key = keys.optString(i);
            JSONObject entry = entries.optJSONObject(key);
            try {
                int id = Integer.parseInt(key);
                if (entry == null || entry.optLong("at", 0) <= now) throw new IllegalStateException();
                armManual(context, id, entry.getLong("at"), entry.optString("title"), entry.optString("body"));
            } catch (Exception stale) {
                entries.remove(key);
                changed = true;
            }
        }
        if (changed) prefs(context).edit().putString(MANUAL_STORE, entries.toString()).commit();
    }

    private static PendingIntent manualIntent(Context context, int id, String title, String body) {
        Intent intent = new Intent(context, ScheduleBoundaryReceiver.class).setAction(MANUAL).putExtra("id", id).putExtra("title", title).putExtra("body", body);
        return PendingIntent.getBroadcast(context, 4000 + (id & 0xFFFF), intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    public static void postManual(Context context, int id, String title, String body) {
        forgetManual(context, id);
        if (!mayNotify(context)) return;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            manager.createNotificationChannel(new NotificationChannel(REMIND_CHANNEL, "Напоминание перед парой", NotificationManager.IMPORTANCE_HIGH));
        }
        Notification notice = new NotificationCompat.Builder(context, REMIND_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_donntu)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(openApp(context))
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build();
        NotificationManagerCompat.from(context).notify(5000 + (id & 0xFFFF), notice);
    }

    public static void stop(Context context) {
        prefs(context).edit().putString(STOPPED_DAY, today()).commit();
        NotificationManagerCompat.from(context).cancel(NOTICE);
    }

    static PendingIntent openApp(Context context) {
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        return PendingIntent.getActivity(context, 0, launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static void remind(Context context, ScheduleSnapshot data, long now) {
        ScheduleSnapshot.Lesson due = data.reminderDue(now);
        if (due == null || !mayNotify(context) || prefs(context).getLong(REMINDED, 0) == due.start) return;
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            manager.createNotificationChannel(new NotificationChannel(REMIND_CHANNEL, "Напоминание перед парой", NotificationManager.IMPORTANCE_HIGH));
        }
        long minutes = Math.max(1, (due.start - now + 59_999) / 60_000);
        Notification notice = new NotificationCompat.Builder(context, REMIND_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_donntu)
            .setContentTitle(due.subject)
            .setContentText("Через " + minutes + " мин · " + due.kind + " · " + due.rooms)
            .setContentIntent(openApp(context))
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setTimeoutAfter(Math.max(1, due.start - now))
            .build();
        NotificationManagerCompat.from(context).notify(REMIND, notice);
        prefs(context).edit().putLong(REMINDED, due.start).commit();
    }

    private static void updateNotification(Context context, ScheduleSnapshot data, long now) {
        NotificationManagerCompat notices = NotificationManagerCompat.from(context);
        ScheduleSnapshot.Lesson current = data.current(now), next = data.next(now);
        boolean ongoing = data.persistent;
        String skip = !data.live && !ongoing ? "выключено" : stoppedToday(context) ? "остановлено на сегодня" : !data.fresh(now) ? "снимок устарел" : current == null && next == null ? "пар нет на 7 дней" : !mayNotify(context) ? "нет разрешения" : !ongoing && !screenLocked(context) ? "экран разблокирован" : null;
        if (skip != null) {
            Log.i(TAG, "блокировка: " + skip);
            notices.cancel(NOTICE);
            return;
        }
        if (wouldWakeScreen(context)) {
            Log.i(TAG, "блокировка: экран выключен, уведомление не трогаем");
            return;
        }
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            if (manager.getNotificationChannel(OLD_CHANNEL) != null) manager.deleteNotificationChannel(OLD_CHANNEL);
            if (manager.getNotificationChannel(OLD_CHANNEL_2) != null) manager.deleteNotificationChannel(OLD_CHANNEL_2);
            String lessonChannel = lessonChannel();
            if (!lessonChannel.equals(LOUD_CHANNEL) && manager.getNotificationChannel(LOUD_CHANNEL) != null) manager.deleteNotificationChannel(LOUD_CHANNEL);
            NotificationChannel channel = new NotificationChannel(lessonChannel, "Пара на экране блокировки и в шторке", hidesOngoingOnLockscreen() ? NotificationManager.IMPORTANCE_HIGH : NotificationManager.IMPORTANCE_LOW);
            channel.setSound(null, null);
            channel.enableVibration(false);
            channel.setShowBadge(false);
            channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            manager.createNotificationChannel(channel);
        }
        ScheduleSnapshot.Lesson lesson = current != null ? current : next;
        long until = current != null ? current.end : next.start;
        boolean later = current == null && !ScheduleSnapshot.sameDay(now, next.start);
        String body = later
            ? ScheduleSnapshot.dayLabel(now, next.start) + " в " + ScheduleSnapshot.clock(next.start) + " · " + lesson.kind + " · " + lesson.rooms
            : lesson.kind + " · " + lesson.rooms + (current != null ? " · до " + ScheduleSnapshot.clock(until) : " · в " + ScheduleSnapshot.clock(until));
        PendingIntent stop = PendingIntent.getBroadcast(context, STOP_REQUEST, new Intent(context, ScheduleBoundaryReceiver.class).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, lessonChannel())
            .setSmallIcon(R.drawable.ic_stat_donntu)
            .setContentTitle(lesson.subject)
            .setContentText(body)
            .setContentIntent(openApp(context))
            .setOngoing(ongoing && !(data.live && hidesOngoingOnLockscreen()))
            .setOnlyAlertOnce(true)
            .setSilent(!hidesOngoingOnLockscreen())
            .setAutoCancel(false)
            .setPriority(hidesOngoingOnLockscreen() ? NotificationCompat.PRIORITY_HIGH : NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setShowWhen(!later)
            .setUsesChronometer(!later)
            .setChronometerCountDown(true)
            .addAction(0, "Остановить на сегодня", stop)
            .setRequestPromotedOngoing(current != null || until - now <= 600_000)
            .setTimeoutAfter(Math.max(1, until - now) + (exactAlarms(context) ? 30_000 : 300_000));
        if (!later) builder.setShortCriticalText(ScheduleSnapshot.clock(until)).setWhen(until);
        notices.notify(NOTICE, builder.build());
        Log.i(TAG, "блокировка: показана пара " + ScheduleSnapshot.clock(lesson.start) + (later ? " другого дня" : ""));
    }
}
