package com.example.ytoffline.yt_offline

// audio_service requires the host Activity to be `AudioServiceActivity`
// (which itself extends `FlutterFragmentActivity`). Plain `FlutterActivity`
// causes audio_service.init to throw with "The Activity class declared in
// your AndroidManifest.xml is wrong or has not provided the correct
// FlutterEngine".
import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val shareChannelName = "yt_offline/share"
    private var shareChannel: MethodChannel? = null

    /// URL or plain text pulled out of the launching intent. Cleared
    /// after Dart calls `getInitial`. Set both on cold launch and on
    /// `onNewIntent` for already-running shares.
    private var pendingShare: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            shareChannelName,
        )
        shareChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitial" -> {
                    val v = pendingShare
                    pendingShare = null
                    result.success(v)
                }
                else -> result.notImplemented()
            }
        }
        // The very first onCreate runs before the engine is wired, so the
        // initial-intent value sits in `pendingShare` waiting for Dart to
        // pull it via getInitial.
        pendingShare = extractShare(intent) ?: pendingShare
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture early so getInitial in configureFlutterEngine can pick it
        // up even if the engine attaches after this call returns.
        pendingShare = extractShare(intent) ?: pendingShare
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val value = extractShare(intent) ?: return
        // App is already running — push the share through the channel so
        // the Dart side reacts without a polling getInitial call.
        val pushed = shareChannel?.invokeMethod("onShare", value)
        if (pushed == null) {
            // Engine not ready yet (e.g. first navigation race). Cache for
            // the next getInitial call.
            pendingShare = value
        }
    }

    /// Returns the shared URL/text if the intent looks like a share, else
    /// null. Handles ACTION_SEND (text/plain) and ACTION_VIEW (URL tap).
    private fun extractShare(intent: Intent?): String? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf {
                        it.isNotBlank()
                    }
                } else null
            }
            Intent.ACTION_VIEW -> intent.dataString?.takeIf { it.isNotBlank() }
            else -> null
        }
    }
}
