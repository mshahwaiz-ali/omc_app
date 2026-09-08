package com.wajid.omc_house

import android.Manifest
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Preserve FragmentActivity for the established biometric flow.
class MainActivity : FlutterFragmentActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val notificationRequestCode = 54319
    private val permissionPreferences by lazy {
        getSharedPreferences("omc_notification_permission", Context.MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "omc/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "permissionState" -> result.success(notificationPermissionState())
                    "requestPermission" -> requestNotificationPermission(result)
                    "openSettings" -> openNotificationSettings(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun notificationPermissionState(): String {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            if (!permissionPreferences.getBoolean("requested", false)) return "notRequested"
            // Android does not reliably distinguish dismissal from permanent denial.
            return if (shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
                "denied"
            } else {
                "previouslyDenied"
            }
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return "settingsRequired"
        if (Build.VERSION.SDK_INT >= 26 &&
            manager.getNotificationChannel("omc_updates")?.importance == NotificationManager.IMPORTANCE_NONE
        ) return "settingsRequired"
        return "granted"
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (permissionResult != null) {
            result.error("request_in_progress", "A notification permission request is already open.", null)
            return
        }
        if (Build.VERSION.SDK_INT < 33 || notificationPermissionState() != "notRequested") {
            result.success(notificationPermissionState())
            return
        }
        permissionPreferences.edit().putBoolean("requested", true).apply()
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequestCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationRequestCode) {
            permissionResult?.success(notificationPermissionState())
            permissionResult = null
        }
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        val appSettings = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        val notificationSettings = if (Build.VERSION.SDK_INT >= 26) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            appSettings
        }
        try {
            try {
                startActivity(notificationSettings)
            } catch (_: ActivityNotFoundException) {
                startActivity(appSettings)
            }
            result.success(null)
        } catch (_: Exception) {
            result.error("settings_unavailable", "Android notification settings could not be opened.", null)
        }
    }
}
