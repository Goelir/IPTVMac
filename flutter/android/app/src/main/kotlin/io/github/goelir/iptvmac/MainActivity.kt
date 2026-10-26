package io.github.goelir.iptvmac

import android.Manifest
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Picture in Picture for the Flutter player (lib/player/android_player_system.dart) and the base class audio_service needs.
 * Dart -> native: isSupported, enter {aspect, playing}, update {aspect, playing, autoEnter}, requestNotificationPermission.
 * Native -> Dart: pipChanged(bool), pipAction() (the play/pause button of the PiP window).
 */
class MainActivity : AudioServiceActivity() {
    private var channel: MethodChannel? = null
    private var aspect = 16.0 / 9.0
    private var playing = false
    private var autoEnter = false

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_PLAY_PAUSE) channel?.invokeMethod("pipAction", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(pipSupported())
                    "isTelevision" -> result.success(isTelevision())
                    "enter" -> {
                        remember(call.argument<Double>("aspect"), call.argument<Boolean>("playing"))
                        result.success(pipSupported() && enterPip())
                    }
                    "update" -> {
                        remember(call.argument<Double>("aspect"), call.argument<Boolean>("playing"))
                        autoEnter = call.argument<Boolean>("autoEnter") ?: false
                        if (pipSupported()) setPictureInPictureParams(params())
                        result.success(null)
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        ContextCompat.registerReceiver(this, actionReceiver, IntentFilter(ACTION_PLAY_PAUSE), ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(actionReceiver) }
        super.onDestroy()
    }

    private fun pipSupported() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun remember(a: Double?, p: Boolean?) {
        // The window accepts ratios between 1:2.39 and 2.39:1; 0 = not known yet.
        aspect = if (a != null && a > 0) a.coerceIn(0.42, 2.39) else 16.0 / 9.0
        playing = p ?: playing
    }

    private fun params(): PictureInPictureParams {
        val b = PictureInPictureParams.Builder()
            .setAspectRatio(Rational((aspect * 1000).toInt(), 1000))
            .setActions(listOf(playPauseAction()))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) b.setAutoEnterEnabled(autoEnter && playing)
        return b.build()
    }

    private fun playPauseAction(): RemoteAction {
        val icon = Icon.createWithResource(this, if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        val intent = PendingIntent.getBroadcast(
            this, 0, Intent(ACTION_PLAY_PAUSE).setPackage(packageName), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return RemoteAction(icon, "Play/Pause", "Play/Pause", intent)
    }

    private fun enterPip(): Boolean = try {
        enterPictureInPictureMode(params())
    } catch (e: IllegalStateException) {
        false
    }

    /** Before Android 12 the system does not enter PiP by itself: do it when the user leaves while a video plays. */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && pipSupported() && autoEnter && playing) enterPip()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4711)
    }

    /** Android TV, Google TV and Fire TV: a remote control and no touch screen (lib/app/device.dart). */
    private fun isTelevision(): Boolean {
        val ui = getSystemService(Context.UI_MODE_SERVICE) as android.app.UiModeManager
        return ui.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION || packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
    }

    companion object {
        private const val CHANNEL = "io.github.goelir.iptvmac/pip"
        private const val ACTION_PLAY_PAUSE = "io.github.goelir.iptvmac.PIP_PLAY_PAUSE"
    }
}
