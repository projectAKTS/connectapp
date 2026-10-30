package com.yakup.helperly

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private var proximityLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "connectapp/callLockScreen")
            .setMethodCallHandler { call, result ->
                if (call.method == "setShowOverLockScreen") {
                    setShowOverLockScreen(call.arguments == true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "connectapp/callProximity")
            .setMethodCallHandler { call, result ->
                if (call.method == "setProximityScreenOff") {
                    setProximityScreenOff(call.arguments == true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        setProximityScreenOff(false)
        super.onDestroy()
    }

    // While an answered call is up, show over the keyguard (without
    // dismissing it) so the call screen opens behind a PIN, like WhatsApp.
    private fun setShowOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    // Screen off at the ear while an audio call is on the earpiece.
    private fun setProximityScreenOff(on: Boolean) {
        if (on) {
            if (proximityLock?.isHeld == true) return
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
            proximityLock = power.newWakeLock(
                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                "helperly:call_proximity",
            ).apply {
                setReferenceCounted(false)
                acquire()
            }
        } else {
            proximityLock?.let {
                if (it.isHeld) it.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY)
            }
            proximityLock = null
        }
    }
}
