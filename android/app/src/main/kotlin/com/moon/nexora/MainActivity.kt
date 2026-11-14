package com.moon.nexora

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val REQUEST_FOREGROUND_NOTIFICATION = 1001
        private const val REQUEST_PLATFORM_PERMISSIONS = 1002
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    private fun currentPermissions(): Map<String, Boolean> {
        val cameraGranted =
            checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        val microphoneGranted =
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val notificationsGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        val bluetoothGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return mapOf(
            "camera" to cameraGranted,
            "microphone" to microphoneGranted,
            "notifications" to notificationsGranted,
            "bluetooth" to bluetoothGranted,
        )
    }

    private fun requiredRuntimePermissions(): List<String> {
        val permissions = mutableListOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        return permissions
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexora/background_connection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= 33 &&
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    REQUEST_FOREGROUND_NOTIFICATION,
                                )
                            }
                            val intent = Intent(this, P2PForegroundService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                            else startService(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.error("BACKGROUND_UNAVAILABLE", "Não foi possível iniciar o serviço de conexão.", null)
                        }
                    }
                    "stop" -> {
                        stopService(Intent(this, P2PForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexora/permissions")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "check" -> result.success(currentPermissions())
                    "request" -> {
                        val missing = requiredRuntimePermissions().filter {
                            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
                        }
                        if (missing.isEmpty()) {
                            result.success(currentPermissions())
                        } else if (pendingPermissionResult != null) {
                            result.success(currentPermissions())
                        } else {
                            pendingPermissionResult = result
                            requestPermissions(missing.toTypedArray(), REQUEST_PLATFORM_PERMISSIONS)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexora/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val title = call.argument<String>("title") ?: "Nexora"
                        val body = call.argument<String>("body") ?: ""
                        val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                        val payload = call.argument<String>("payload")

                        val notificationManager = getSystemService(NotificationManager::class.java)
                        val channelId = "nexora.alerts"
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = NotificationChannel(
                                channelId,
                                "Mensagens e Chamadas",
                                NotificationManager.IMPORTANCE_HIGH
                            ).apply {
                                description = "Notificações de mensagens, chamadas e alertas do Nexora."
                                enableVibration(true)
                                setShowBadge(true)
                            }
                            notificationManager.createNotificationChannel(channel)
                        }

                        val intent = Intent(this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            putExtra("payload", payload)
                        }
                        val pendingIntent = PendingIntent.getActivity(
                            this,
                            id,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Notification.Builder(this, channelId)
                        } else {
                            Notification.Builder(this)
                        }
                        val notification = builder
                            .setSmallIcon(R.drawable.ic_stat_nexora)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setContentIntent(pendingIntent)
                            .setAutoCancel(true)
                            .setPriority(Notification.PRIORITY_HIGH)
                            .setDefaults(Notification.DEFAULT_ALL)
                            .build()

                        notificationManager.notify(id, notification)
                        result.success(true)
                    }
                    "clearAll" -> {
                        val notificationManager = getSystemService(NotificationManager::class.java)
                        notificationManager.cancelAll()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PLATFORM_PERMISSIONS) {
            val callback = pendingPermissionResult
            pendingPermissionResult = null
            callback?.success(currentPermissions())
        }
    }

    override fun onDestroy() {
        pendingPermissionResult = null
        if (isFinishing) stopService(Intent(this, P2PForegroundService::class.java))
        super.onDestroy()
    }
}
