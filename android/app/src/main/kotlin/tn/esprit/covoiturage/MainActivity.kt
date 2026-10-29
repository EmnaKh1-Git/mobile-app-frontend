package tn.esprit.covoiturage

import android.media.MediaPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaPlayer: MediaPlayer? = null
    private var audioEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "covoiturage/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Le fichier audio est introuvable.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        mediaPlayer?.release()
                        mediaPlayer = MediaPlayer().apply {
                            setDataSource(path)
                            setOnCompletionListener {
                                release()
                                mediaPlayer = null
                                audioEventSink?.success("completed")
                            }
                            prepare()
                            start()
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        mediaPlayer?.release()
                        mediaPlayer = null
                        result.error("PLAYBACK_ERROR", error.message, null)
                    }
                }
                "stop" -> {
                    mediaPlayer?.stop()
                    mediaPlayer?.release()
                    mediaPlayer = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "covoiturage/audio_events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                audioEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                audioEventSink = null
            }
        })
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }
}

