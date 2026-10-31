package ru.donntu.schedule;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public final class ScheduleBoundaryReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        PendingResult pending = goAsync();
        new Thread(() -> {
            try {
                if (ScheduleRuntime.MANUAL.equals(intent.getAction())) {
                    ScheduleRuntime.postManual(context, intent.getIntExtra("id", 0), intent.getStringExtra("title"), intent.getStringExtra("body"));
                    return;
                }
                if (ScheduleRuntime.STOP.equals(intent.getAction())) ScheduleRuntime.stop(context);
                ScheduleRuntime.refresh(context);
                ScheduleWidgetProvider.refresh(context);
                ChangeWatch.check(context);
                ScheduleRuntime.refresh(context);
            } catch (Exception error) {
                Log.w("DonntuSchedule", "Не удалось обновить расписание", error);
            } finally {
                pending.finish();
            }
        }, "schedule-boundary").start();
    }
}
