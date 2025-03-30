package com.gunschu.jitsi_meet

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import com.gunschu.jitsi_meet.JitsiMeetPlugin.Companion.JITSI_MEETING_CLOSE
import com.gunschu.jitsi_meet.JitsiMeetPlugin.Companion.JITSI_PLUGIN_TAG
import org.jitsi.meet.sdk.JitsiMeetActivity
import org.jitsi.meet.sdk.JitsiMeetConferenceOptions

class JitsiMeetPluginActivity : JitsiMeetActivity() {

    companion object {
        @JvmStatic
        fun launchActivity(
            context: Context?,
            options: JitsiMeetConferenceOptions
        ) {
            val intent = Intent(context, JitsiMeetPluginActivity::class.java).apply {
                action = "org.jitsi.meet.CONFERENCE"
                putExtra("JitsiMeetConferenceOptions", options)
            }
            context?.startActivity(intent)
        }
    }

    private var onStopCalled: Boolean = false

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)

        if (isInPictureInPictureMode) {
            JitsiMeetEventStreamHandler.instance.onPictureInPictureWillEnter()
        } else {
            JitsiMeetEventStreamHandler.instance.onPictureInPictureTerminated()
        }

        if (!isInPictureInPictureMode && onStopCalled) {
            getJitsiView().leave()
        }
    }

    private val myReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == JITSI_MEETING_CLOSE) {
                finish()
            }
        }
    }

    override fun onStop() {
        super.onStop()
        onStopCalled = true
        unregisterReceiver(myReceiver)
    }

    override fun onResume() {
        super.onResume()
        onStopCalled = false
        registerReceiver(myReceiver, IntentFilter(JITSI_MEETING_CLOSE))
    }

    override fun onConferenceWillJoin(data: HashMap<String, Any>) {
        Log.d(JITSI_PLUGIN_TAG, "onConferenceWillJoin: $data")
        JitsiMeetEventStreamHandler.instance.onConferenceWillJoin(data)
        super.onConferenceWillJoin(data)
    }

    override fun onConferenceJoined(data: HashMap<String, Any>) {
        Log.d(JITSI_PLUGIN_TAG, "onConferenceJoined: $data")
        JitsiMeetEventStreamHandler.instance.onConferenceJoined(data)
        super.onConferenceJoined(data)
    }

    override fun onConferenceTerminated(data: HashMap<String, Any>) {
        Log.d(JITSI_PLUGIN_TAG, "onConferenceTerminated: $data")
        JitsiMeetEventStreamHandler.instance.onConferenceTerminated(data)
        super.onConferenceTerminated(data)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        turnScreenOnAndKeyguardOff()
    }

    override fun onDestroy() {
        super.onDestroy()
        turnScreenOffAndKeyguardOn()
    }

    private fun turnScreenOnAndKeyguardOff() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
            )
        }
    }

    private fun turnScreenOffAndKeyguardOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        } else {
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
            )
        }
    }
}
