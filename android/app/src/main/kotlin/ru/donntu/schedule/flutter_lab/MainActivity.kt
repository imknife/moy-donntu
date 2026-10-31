package ru.donntu.schedule.flutter_lab

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import ru.donntu.schedule.ScheduleRuntime
import ru.donntu.schedule.ScheduleWidgetProvider

class MainActivity : FlutterActivity() {
    override fun getInitialRoute(): String? = "/"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.donntu.schedule/native").setMethodCallHandler { call, result ->
            try {
                result.success(handle(call))
            } catch (error: Exception) {
                result.error("native", error.message, null)
            }
        }
    }

    private fun handle(call: MethodCall): Any? {
        val context: Context = applicationContext
        return when (call.method) {
            "openCalendar" -> openCalendar(context, call.arguments as String)
            "sync" -> {
                val raw = call.arguments as String
                require(raw.length <= 2_000_000) { "Слишком большой снимок" }
                ScheduleRuntime.save(context, raw)
                ScheduleRuntime.refresh(context)
                ScheduleWidgetProvider.refresh(context)
                true
            }
            "refresh" -> {
                val exact = ScheduleRuntime.refresh(context)
                ScheduleWidgetProvider.refresh(context)
                exact
            }
            "resume" -> {
                ScheduleRuntime.resume(context)
                ScheduleRuntime.refresh(context)
                true
            }
            "status" -> ScheduleRuntime.status(context).toString()
            "requestNotifications" -> {
                if (Build.VERSION.SDK_INT >= 33) ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 7001)
                true
            }
            "scheduleManual" -> {
                val args = call.arguments as Map<*, *>
                ScheduleRuntime.scheduleManual(context, (args["id"] as Number).toInt(), (args["at"] as Number).toLong(), args["title"] as String, args["body"] as String)
            }
            "cancelManual" -> {
                ScheduleRuntime.cancelManual(context, (call.arguments as Number).toInt())
                true
            }
            "openSettings" -> openSettings(context, call.arguments as String)
            else -> throw IllegalArgumentException("Неизвестный вызов")
        }
    }

    private fun openCalendar(context: Context, path: String): Boolean {
        val file = java.io.File(path).canonicalFile
        val allowed = java.io.File(context.cacheDir, "share_plus").canonicalFile
        require(file.path.startsWith(allowed.path + java.io.File.separator)) { "Недопустимый путь" }
        val uri = FileProvider.getUriForFile(context, context.packageName + ".flutter.share_provider", file)
        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "text/calendar").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openSettings(context: Context, target: String): Boolean {
        val pkg = Uri.parse("package:" + context.packageName)
        val candidates = when (target) {
            "exactAlarms" -> listOf(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg))
            "notifications" -> listOf(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
            "promoted" -> listOf(
                Intent("android.settings.MANAGE_APP_PROMOTED_NOTIFICATIONS").putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg),
            )
            "autostart" -> listOf(
                Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
                Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")),
                Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.PurviewTabActivity")),
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg),
            )
            else -> listOf(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
        }
        for (intent in candidates) {
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }
}
