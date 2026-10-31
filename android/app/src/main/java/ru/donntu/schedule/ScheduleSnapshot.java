package ru.donntu.schedule;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public final class ScheduleSnapshot {
    public static final ZoneId MOSCOW = ZoneId.of("Europe/Moscow");
    private static final String[] DAYS = {"Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"};
    public final String group;
    public final boolean live;
    public final boolean persistent;
    public final int remind;
    public final long updatedAt;
    public final List<Lesson> lessons;
    public final List<LocalDate> dates;

    public ScheduleSnapshot(String group, boolean live, boolean persistent, int remind, long updatedAt, List<Lesson> lessons, List<LocalDate> dates) {
        this.group = group;
        this.live = live;
        this.persistent = persistent;
        this.remind = remind;
        this.updatedAt = updatedAt;
        this.lessons = new ArrayList<>(lessons);
        this.lessons.sort(Comparator.comparingLong(l -> l.start));
        this.dates = new ArrayList<>(dates);
    }

    public static long instant(String date, int minute) {
        return LocalDate.parse(date).atStartOfDay(MOSCOW).plusMinutes(minute).toInstant().toEpochMilli();
    }

    public static LocalDate dateOf(long millis) {
        return Instant.ofEpochMilli(millis).atZone(MOSCOW).toLocalDate();
    }

    public static String time(long millis) {
        return Instant.ofEpochMilli(millis).atZone(MOSCOW).format(DateTimeFormatter.ofPattern("H:mm"));
    }

    public static String clock(long millis) {
        return Instant.ofEpochMilli(millis).atZone(MOSCOW).format(DateTimeFormatter.ofPattern("HH:mm"));
    }

    public static String nextLabel(long now, long start) {
        return sameDay(now, start) ? clock(start) : dayLabel(now, start) + " · " + clock(start);
    }

    public static boolean sameDay(long a, long b) {
        return dateOf(a).equals(dateOf(b));
    }

    public static String dayLabel(long now, long start) {
        LocalDate today = dateOf(now);
        LocalDate date = dateOf(start);
        if (date.equals(today)) return "Сегодня";
        if (date.equals(today.plusDays(1))) return "Завтра";
        return DAYS[date.getDayOfWeek().getValue() - 1];
    }

    public boolean fresh(long now) {
        return dates.contains(dateOf(now));
    }

    public List<Lesson> day(long now) {
        List<Lesson> out = new ArrayList<>();
        LocalDate today = dateOf(now);
        for (Lesson l : lessons) if (dateOf(l.start).equals(today)) out.add(l);
        return out;
    }

    public Lesson current(long now) {
        if (!fresh(now)) return null;
        for (Lesson l : lessons) if (l.start <= now && now < l.end) return l;
        return null;
    }

    public Lesson next(long now) {
        if (!fresh(now)) return null;
        for (Lesson l : lessons) if (l.start > now) return l;
        return null;
    }

    public Lesson reminderDue(long now) {
        if (remind <= 0 || !fresh(now)) return null;
        for (Lesson l : lessons) {
            long at = l.start - remind * 60_000L;
            if (at <= now && now < l.start) return l;
        }
        return null;
    }

    public long nextBoundary(long now) {
        if (!fresh(now)) return 0;
        long boundary = dateOf(now).plusDays(1).atStartOfDay(MOSCOW).toInstant().toEpochMilli();
        for (Lesson l : lessons) {
            if (l.start > now) boundary = Math.min(boundary, l.start);
            if (l.end > now) boundary = Math.min(boundary, l.end);
            long at = l.start - remind * 60_000L;
            if (remind > 0 && at > now) boundary = Math.min(boundary, at);
        }
        return boundary;
    }

    public static final class Lesson {
        public final long start, end;
        public final String subject, kind, rooms;
        public String teacher = "", change = "";

        public Lesson(long start, long end, String subject, String kind, String rooms) {
            this.start = start;
            this.end = end;
            this.subject = subject;
            this.kind = kind;
            this.rooms = rooms;
        }
    }
}
