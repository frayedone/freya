package kz.freya.freya

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        installChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("badArg", "path required", null)
                    } else {
                        try {
                            installApk(path)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install", e.message ?: e.toString(), null)
                        }
                    }
                }
                "updateDir" -> {
                    val dir = File(cacheDir, "updates")
                    if (!dir.exists()) dir.mkdirs()
                    result.success(dir.absolutePath)
                }
                "canInstall" -> result.success(canInstallPackages())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(null)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("badArg", "url required", null)
                    } else {
                        try {
                            openUrl(url)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("url", e.message ?: e.toString(), null)
                        }
                    }
                }
                "canScheduleExactAlarms" -> result.success(canExactAlarms())
                "requestExactAlarms" -> {
                    requestExactAlarms()
                    result.success(canExactAlarms())
                }
                "openBatterySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("battery", e.message ?: e.toString(), null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        installChannel = null
        super.onDestroy()
    }

    private fun canExactAlarms(): Boolean {
        val am = getSystemService(ALARM_SERVICE) as? AlarmManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun requestExactAlarms() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (_: Exception) {
            // на части прошивок экрана нет — просто пропускаем
        }
    }

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (_: Exception) {
            // экрана нет — не страшно
        }
    }

    private fun openUrl(url: String) {
        startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /**
     * Установка APK через PackageInstaller-сессию.
     *
     * Это надёжнее, чем ACTION_VIEW: система сама копирует файл из
     * приватного кэша, а результат приходит в [InstallResultReceiver],
     * откуда код ошибки уходит в приложение.
     */
    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalStateException("Файл обновления не найден")
        }
        if (file.length() == 0L) {
            throw IllegalStateException("Файл обновления пустой")
        }
        if (!canInstallPackages()) {
            openInstallSettings()
            throw IllegalStateException(
                "Разреши установку приложений из Freya и нажми «Установить» снова"
            )
        }
        try {
            installViaSession(file)
        } catch (_: Exception) {
            // PackageInstaller не сработал — падаем на классический путь
            installApkLegacy(file)
        }
    }

    private fun installViaSession(file: File) {
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        params.setAppPackageName(packageName)

        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            session.openWrite("freya_update", 0, file.length()).use { out ->
                file.inputStream().use { input -> input.copyTo(out) }
                session.fsync(out)
            }
            val intent = Intent(ACTION_INSTALL_COMMIT).setPackage(packageName)
            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val pending = PendingIntent.getBroadcast(this, sessionId, intent, pendingFlags)
            session.commit(pending.intentSender)
        }
    }

    /**
     * Резервный путь: открыть системный установщик напрямую.
     * Используется, если PackageInstaller-сессия не удалась.
     */
    private fun installApkLegacy(file: File) {
        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.clipData = ClipData.newRawUri("apk", uri)
        startActivity(intent)
    }

    companion object {
        private const val CHANNEL = "kz.freya.freya/updates"
        private const val ACTION_INSTALL_COMMIT = "kz.freya.freya.INSTALL_COMMIT"

        /** Ссылка на канал, чтобы принимать отчёт об установке. */
        @JvmStatic
        internal var installChannel: MethodChannel? = null

        /** Отправляет в приложение код/текст ошибки установки. */
        @JvmStatic
        internal fun reportInstallResult(status: Int, message: String?) {
            val channel = installChannel ?: return
            channel.invokeMethod(
                "installResult",
                mapOf(
                    "status" to status,
                    "message" to (message ?: ""),
                    "reason" to describeInstallStatus(status, message),
                )
            )
        }

        @JvmStatic
        internal fun describeInstallStatus(status: Int, message: String?): String {
            val known = when (status) {
                PackageInstaller.STATUS_FAILURE_ABORTED -> "Установка прервана"
                PackageInstaller.STATUS_FAILURE_BLOCKED -> "Установка заблокирована устройством"
                PackageInstaller.STATUS_FAILURE_CONFLICT -> "Конфликт с установленной версией"
                PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> "APK несовместим с устройством"
                PackageInstaller.STATUS_FAILURE_INVALID -> "Проблема с файлом приложения"
                PackageInstaller.STATUS_FAILURE_STORAGE -> "Недостаточно места"
                else -> "Не удалось установить приложение"
            }
            val details = message?.trim().orEmpty()
            return if (details.isEmpty()) known else "$known ($details)"
        }

    }
}

/** Ловит результат PackageInstaller.commit и передаёт его в Dart. */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val status = intent?.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        ) ?: return
        if (status == PackageInstaller.STATUS_SUCCESS) return
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        MainActivity.reportInstallResult(status, message)
    }
}
