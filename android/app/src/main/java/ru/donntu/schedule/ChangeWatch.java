package ru.donntu.schedule;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import org.json.JSONArray;
import org.json.JSONObject;
import ru.donntu.schedule.flutter_lab.R;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

public final class ChangeWatch {
    private static final String CHANNEL = "schedule_changes";
    private static final int NOTICE = 3500;

    private ChangeWatch() { }

    public static void check(Context context) {
        SharedPreferences store = context.getSharedPreferences("DonntuSchedule", Context.MODE_PRIVATE);
        try {
            JSONObject snapshot = new JSONObject(store.getString("ds_widget", ""));
            String api = snapshot.optString("apiUrl");
            String group = snapshot.optString("groupCode");
            if (api.isEmpty() || group.isEmpty()) return;
            String seenKey = "ds_seen_" + group;
            long seen = Math.max(store.getLong(seenKey, -1), snapshot.optLong("seen", 0));
            JSONObject pkg = fetch(api + "/groups/" + URLEncoder.encode(group, "UTF-8").replace("+", "%20") + "/package");
            long version = pkg.optLong("version", 0);
            boolean first = store.getLong(seenKey, -1) < 0 && snapshot.optLong("seen", 0) == 0;
            if (first || version <= seen) {
                store.edit().putLong(seenKey, Math.max(seen, version)).commit();
                return;
            }
            store.edit().putLong(seenKey, version).commit();
            if (!snapshot.optBoolean("changeAlerts", true) || !ScheduleRuntime.mayNotify(context)) return;
            notice(context, summary(pkg));
        } catch (Exception error) {
            Log.w("DonntuSchedule", "Проверка изменений не удалась", error);
        }
    }

    private static JSONObject fetch(String address) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(address).openConnection();
        connection.setConnectTimeout(8000);
        connection.setReadTimeout(8000);
        connection.setRequestProperty("Accept", "application/json");
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), StandardCharsets.UTF_8))) {
            StringBuilder out = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) out.append(line);
            return new JSONObject(out.toString());
        } finally {
            connection.disconnect();
        }
    }

    private static String describe(JSONObject change) {
        String type = change.optString("type");
        if (type.equals("added")) return "новая пара";
        if (type.equals("removed")) return "пара убрана";
        JSONArray fields = change.optJSONArray("fields");
        if (fields == null) return "";
        for (int i = 0; i < fields.length(); i++) {
            JSONObject f = fields.optJSONObject(i);
            if (f == null) continue;
            if (f.optString("field").equals("teachers")) return "другой преподаватель";
            if (f.optString("field").equals("rooms")) return "аудитория: " + (f.optString("to").isEmpty() ? "не указана" : f.optString("to"));
            if (f.optString("field").equals("subject")) return "другой предмет";
        }
        return fields.length() > 0 ? "изменено" : "";
    }

    private static String summary(JSONObject pkg) {
        JSONObject last = pkg.optJSONObject("lastChange");
        JSONObject diff = last == null ? null : last.optJSONObject("diff");
        JSONArray changes = diff == null ? null : diff.optJSONArray("changes");
        if (changes == null || changes.length() == 0) return "Откройте расписание";
        JSONObject first = changes.optJSONObject(0);
        String what = describe(first);
        String head = first.optString("subject") + (what.isEmpty() ? "" : " — " + what);
        int more = changes.length() - 1;
        return more > 0 ? head + " и ещё " + more : head;
    }

    private static void notice(Context context, String body) {
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Изменения расписания", NotificationManager.IMPORTANCE_HIGH));
        }
        Notification built = new NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_donntu)
            .setContentTitle("Расписание изменилось")
            .setContentText(body)
            .setContentIntent(ScheduleRuntime.openApp(context))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build();
        NotificationManagerCompat.from(context).notify(NOTICE, built);
    }
}
