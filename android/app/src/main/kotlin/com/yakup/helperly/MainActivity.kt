package com.yakup.helperly

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

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
        // Shrinks a chosen post video before upload. Answers the new file's
        // path, or null to keep the original.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "connectapp/videoCompress")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (call.method != "compress") {
                    result.notImplemented()
                } else if (path == null) {
                    result.success(null)
                } else {
                    compressVideo(path, result)
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

    @OptIn(UnstableApi::class)
    private fun compressVideo(path: String, result: MethodChannel.Result) {
        val out = File(cacheDir, "post_${System.currentTimeMillis()}.mp4")
        var durationMs = 0L
        var shownW = 0
        var shownH = 0
        try {
            val r = MediaMetadataRetriever()
            r.setDataSource(path)
            fun meta(key: Int) = r.extractMetadata(key)?.toIntOrNull() ?: 0
            durationMs = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val w = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val h = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val turned = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) % 180 != 0
            shownW = if (turned) h else w
            shownH = if (turned) w else h
            r.release()
        } catch (e: Exception) {
        }
        // 720p for short clips; 540p keeps long ones (up to 3 min) small.
        val shortSide = if (durationMs > 60_000) 540 else 720
        // Output height for that short side, in the upright picture.
        val outH = when {
            shownW <= 0 || shownH <= 0 -> shortSide
            shownH > shownW -> (shownH.toLong() * shortSide / shownW).toInt() and 1.inv()
            else -> shortSide
        }
        val shrink = shownW <= 0 || minOf(shownW, shownH) > shortSide
        val bitrate = if (shortSide == 720) 2_500_000 else 1_500_000
        var answered = false
        fun answer(value: String?) {
            if (answered) return
            answered = true
            if (value == null) out.delete()
            result.success(value)
        }
        try {
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
                .setEffects(
                    Effects(
                        listOf(),
                        if (shrink) listOf(Presentation.createForHeight(outH)) else listOf()
                    )
                )
                .build()
            val encoders = DefaultEncoderFactory.Builder(this)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder().setBitrate(bitrate).build()
                )
                .build()
            Transformer.Builder(this)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoders)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        answer(out.absolutePath)
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        answer(null)
                    }
                })
                .build()
                .start(item, out.absolutePath)
        } catch (e: Exception) {
            answer(null)
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
