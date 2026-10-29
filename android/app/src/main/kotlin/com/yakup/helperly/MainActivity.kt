package com.yakup.helperly

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeForAcceptedCall(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        wakeForAcceptedCall(intent)
    }

    override fun onResume() {
        super.onResume()
        // Only the accept launch may turn the screen on; later resumes must not.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            window.decorView.postDelayed({ setTurnScreenOn(false) }, 1000)
        }
    }

    // A call answered from the notification while the screensaver (dream) is
    // showing opens this activity behind the dream. Turning the screen on
    // wakes the device, which ends the dream and shows the call screen.
    private fun wakeForAcceptedCall(intent: Intent?) {
        if (intent?.action != ACTION_CALL_ACCEPT) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) setTurnScreenOn(true)
    }

    companion object {
        private const val ACTION_CALL_ACCEPT =
            "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT"
    }
}
