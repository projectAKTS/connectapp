package com.yakup.helperly

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.os.PowerManager

class HelperlyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(AcceptedCallWaker)
    }

    // A call answered from the notification while the screensaver (dream) is
    // showing opens the app behind the dream, so MainActivity never becomes
    // visible and receives nothing until the user touches the screen. The
    // plugin's accept trampoline is created right away, so the device is woken
    // there: a wake lock with ACQUIRE_CAUSES_WAKEUP ends the dream.
    private object AcceptedCallWaker : ActivityLifecycleCallbacks {
        private const val ACCEPT_TRAMPOLINE =
            "com.hiennv.flutter_callkit_incoming.TransparentActivity"
        private const val ACTION_CALL_ACCEPT =
            "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT"
        private const val WAKE_MS = 3000L

        @Suppress("DEPRECATION")
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
            if (activity.javaClass.name != ACCEPT_TRAMPOLINE) return
            if (activity.intent?.action != ACTION_CALL_ACCEPT) return
            try {
                val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
                power.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "helperly:accepted_call",
                ).acquire(WAKE_MS)
            } catch (_: RuntimeException) {
            }
        }

        override fun onActivityStarted(activity: Activity) {}
        override fun onActivityResumed(activity: Activity) {}
        override fun onActivityPaused(activity: Activity) {}
        override fun onActivityStopped(activity: Activity) {}
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
        override fun onActivityDestroyed(activity: Activity) {}
    }
}
