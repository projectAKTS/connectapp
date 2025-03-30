package com.gunschu.jitsi_meet

import android.app.Activity
import android.content.Intent
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import org.jitsi.meet.sdk.JitsiMeetConferenceOptions
import org.jitsi.meet.sdk.JitsiMeetUserInfo
import java.net.URL

class JitsiMeetPlugin() : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null

    // Allow a nullable Activity to avoid "argument type mismatch"
    constructor(activity: Activity?) : this() {
        this.activity = activity
    }

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            // If the registrar has an activity, pass it; otherwise pass null
            val plugin = JitsiMeetPlugin(registrar.activity())
            val channel = MethodChannel(registrar.messenger(), JITSI_METHOD_CHANNEL)
            channel.setMethodCallHandler(plugin)

            val eventChannel = EventChannel(registrar.messenger(), JITSI_EVENT_CHANNEL)
            eventChannel.setStreamHandler(JitsiMeetEventStreamHandler.instance)
        }

        const val JITSI_PLUGIN_TAG = "JITSI_MEET_PLUGIN"
        const val JITSI_METHOD_CHANNEL = "jitsi_meet"
        const val JITSI_EVENT_CHANNEL = "jitsi_meet_events"
        const val JITSI_MEETING_CLOSE = "JITSI_MEETING_CLOSE"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, JITSI_METHOD_CHANNEL)
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, JITSI_EVENT_CHANNEL)
        eventChannel.setStreamHandler(JitsiMeetEventStreamHandler.instance)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d(JITSI_PLUGIN_TAG, "method: ${call.method}")
        Log.d(JITSI_PLUGIN_TAG, "arguments: ${call.arguments}")

        when (call.method) {
            "joinMeeting" -> {
                joinMeeting(call, result)
            }
            "closeMeeting" -> {
                closeMeeting(call, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun joinMeeting(call: MethodCall, result: Result) {
        val room = call.argument<String>("room")
        if (room.isNullOrBlank()) {
            result.error("400", "room cannot be null or empty", null)
            return
        }

        Log.d(JITSI_PLUGIN_TAG, "Joining Room: $room")

        val userInfo = JitsiMeetUserInfo().apply {
            displayName = call.argument("userDisplayName")
            email = call.argument("userEmail")
            val avatarURL = call.argument<String>("userAvatarURL")
            if (!avatarURL.isNullOrEmpty()) {
                avatar = URL(avatarURL)
            }
        }

        var serverURLString = call.argument<String>("serverURL")
        if (serverURLString.isNullOrBlank()) {
            serverURLString = "https://meet.jit.si"
        }
        val serverURL = URL(serverURLString)
        Log.d(JITSI_PLUGIN_TAG, "Server URL: $serverURL")

        val optionsBuilder = JitsiMeetConferenceOptions.Builder()
            .setServerURL(serverURL)
            .setRoom(room)
            .setSubject(call.argument("subject"))
            .setToken(call.argument("token"))
            .setAudioMuted(call.argument("audioMuted") ?: false)
            .setAudioOnly(call.argument("audioOnly") ?: false)
            .setVideoMuted(call.argument("videoMuted") ?: false)
            .setUserInfo(userInfo)

        // Feature flags
        val featureFlags = call.argument<HashMap<String, Any>>("featureFlags")
        featureFlags?.forEach { (key, value) ->
            when (value) {
                is Boolean -> optionsBuilder.setFeatureFlag(key, value)
                is Int -> optionsBuilder.setFeatureFlag(key, value)
                else -> {
                    // no-op if type is unexpected
                }
            }
        }

        val options = optionsBuilder.build()

        // Ensure we have a non-null Activity
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No attached Activity. Are you in background?", null)
            return
        }

        JitsiMeetPluginActivity.launchActivity(currentActivity, options)
        result.success("Successfully joined room: $room")
    }

    private fun closeMeeting(call: MethodCall, result: Result) {
        val intent = Intent(JITSI_MEETING_CLOSE)
        activity?.sendBroadcast(intent)
        result.success(null)
    }

    /**
     * ActivityAware interface
     */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        this.activity = null
    }
}
