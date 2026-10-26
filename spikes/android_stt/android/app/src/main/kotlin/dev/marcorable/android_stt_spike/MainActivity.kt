package dev.marcorable.android_stt_spike

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.ModelDownloadListener
import android.speech.SpeechRecognizer
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor

class MainActivity : FlutterActivity(), RecognitionListener {
    private var recognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingStart = false
    private var lastRmsEventAt = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(capabilities())
                "start" -> {
                    startRecognition()
                    result.success(null)
                }
                "stop" -> {
                    recognizer?.stopListening()
                    result.success(null)
                }
                "cancel" -> {
                    recognizer?.cancel()
                    result.success(null)
                }
                "checkSupport" -> checkSupport(result)
                "downloadModel" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
                            result.error("unavailable", "온디바이스 인식을 사용할 수 없습니다.", null)
                            return@setMethodCallHandler
                        }
                        recognizer?.destroy()
                        recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this).also {
                            it.setRecognitionListener(this)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                                it.triggerModelDownload(
                                    recognitionIntent(),
                                    mainExecutor,
                                    object : ModelDownloadListener {
                                        override fun onProgress(completedPercent: Int) =
                                            emit("modelProgress", code = completedPercent)

                                        override fun onSuccess() = emit("modelReady")

                                        override fun onScheduled() = emit("modelScheduled")

                                        override fun onError(error: Int) =
                                            emit("error", error = "모델 다운로드 오류", code = error)
                                    },
                                )
                            } else {
                                it.triggerModelDownload(recognitionIntent())
                                emit("modelRequested")
                            }
                        }
                        result.success(null)
                    } else {
                        result.error("unsupported", "API 33 이상이 필요합니다.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    private fun capabilities() = mapOf(
        "sdk" to Build.VERSION.SDK_INT,
        "recognitionAvailable" to SpeechRecognizer.isRecognitionAvailable(this),
        "onDeviceAvailable" to SpeechRecognizer.isOnDeviceRecognitionAvailable(this),
        "locale" to LOCALE,
    )

    private fun startRecognition() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingStart = true
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), AUDIO_PERMISSION_REQUEST)
            return
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            emit("error", error = "온디바이스 음성 인식 서비스를 사용할 수 없습니다.")
            return
        }
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this).also {
            it.setRecognitionListener(this)
            it.startListening(recognitionIntent())
        }
        emit("starting")
    }

    private fun recognitionIntent() = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, LOCALE)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            putExtra(RecognizerIntent.EXTRA_ENABLE_FORMATTING, RecognizerIntent.FORMATTING_OPTIMIZE_LATENCY)
            putExtra(RecognizerIntent.EXTRA_HIDE_PARTIAL_TRAILING_PUNCTUATION, true)
        }
    }

    private fun checkSupport(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            result.error("unsupported", "온디바이스 지원 확인을 실행할 수 없습니다.", null)
            return
        }
        checkSupportApi33(result)
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun checkSupportApi33(result: MethodChannel.Result) {
        val probe = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        val executor = Executor { command -> runOnUiThread(command) }
        probe.checkRecognitionSupport(recognitionIntent(), executor, object : RecognitionSupportCallback {
            override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                result.success(mapOf(
                    "installed" to recognitionSupport.installedOnDeviceLanguages,
                    "pending" to recognitionSupport.pendingOnDeviceLanguages,
                    "supported" to recognitionSupport.supportedOnDeviceLanguages,
                    "online" to recognitionSupport.onlineLanguages,
                ))
                probe.destroy()
            }

            override fun onError(error: Int) {
                result.error("support_$error", errorName(error), null)
                probe.destroy()
            }
        })
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != AUDIO_PERMISSION_REQUEST) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED && pendingStart) {
            pendingStart = false
            startRecognition()
        } else {
            pendingStart = false
            emit("error", error = "마이크 권한이 거부되었습니다.")
        }
    }

    override fun onReadyForSpeech(params: Bundle?) = emit("ready")
    override fun onBeginningOfSpeech() = emit("speechStart")
    override fun onRmsChanged(rmsdB: Float) {
        val now = System.currentTimeMillis()
        if (now - lastRmsEventAt >= 500) {
            lastRmsEventAt = now
            emit("rms", text = "%.1f dB".format(rmsdB))
        }
    }
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() = emit("speechEnd")
    override fun onError(error: Int) = emit("error", error = errorName(error), code = error)
    override fun onPartialResults(partialResults: Bundle?) = emitResults("partial", partialResults)
    override fun onResults(results: Bundle?) = emitResults("final", results)
    override fun onEvent(eventType: Int, params: Bundle?) {}

    private fun emitResults(type: String, bundle: Bundle?) {
        val values = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
        emit(type, text = values.firstOrNull().orEmpty(), alternatives = values)
    }

    private fun emit(
        type: String,
        text: String? = null,
        alternatives: List<String>? = null,
        error: String? = null,
        code: Int? = null,
    ) {
        val payload = mutableMapOf<String, Any>("type" to type, "timestampMs" to System.currentTimeMillis())
        text?.let { payload["text"] = it }
        alternatives?.let { payload["alternatives"] = it }
        error?.let { payload["error"] = it }
        code?.let { payload["code"] = it }
        runOnUiThread { eventSink?.success(payload) }
    }

    private fun errorName(error: Int) = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "오디오 입력 오류"
        SpeechRecognizer.ERROR_CLIENT -> "클라이언트 취소 또는 상태 오류"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "마이크 권한 없음"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "ko-KR 미지원"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "ko-KR 모델 미설치"
        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "네트워크 오류(온디바이스 경로 위반 가능)"
        SpeechRecognizer.ERROR_NO_MATCH -> "인식 결과 없음"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "인식기 사용 중"
        SpeechRecognizer.ERROR_SERVER, SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "인식 서비스 오류"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "음성 입력 시간 초과"
        else -> "알 수 없는 오류 $error"
    }

    override fun onDestroy() {
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        super.onDestroy()
    }

    companion object {
        private const val METHODS = "dev.marcorable.recitescripts/stt_methods"
        private const val EVENTS = "dev.marcorable.recitescripts/stt_events"
        private const val LOCALE = "ko-KR"
        private const val AUDIO_PERMISSION_REQUEST = 1201
    }
}
