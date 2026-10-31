package com.marcorable.maltto

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Looper
import android.speech.ModelDownloadListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import java.util.Locale
import kotlin.coroutines.resume

internal class AndroidSpeechAdapter(
    private val activity: Activity,
    binaryMessenger: BinaryMessenger,
) : NativeSttHostApi {
    private data class StartReservation(
        val sessionId: String,
        val generation: Long,
    )

    private val flutterApi = NativeSttFlutterApi(binaryMessenger)
    private val eventScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val permissionManager = RecordAudioPermissionManager(activity)
    private var activeSession: AndroidSpeechSession? = null
    private var pendingStart: StartReservation? = null
    private val modelStatusCache = mutableMapOf<String, NativeSttModelStatus>()
    private val supportRecognizers = mutableSetOf<SpeechRecognizer>()
    private val modelDownloadRecognizers = mutableMapOf<String, SpeechRecognizer>()
    private var disposed = false

    override suspend fun checkAvailability(locale: String): NativeSttAvailability {
        ensureActiveAndMainThread()
        val permission = permissionManager.currentPermission()
        val onDeviceAvailable = SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)
        val modelStatus =
            if (onDeviceAvailable) {
                try {
                    queryModelStatus(locale)
                } catch (_: FlutterError) {
                    modelStatusCache.remove(localeKey(locale))
                    NativeSttModelStatus.UNSUPPORTED
                }
            } else {
                NativeSttModelStatus.UNSUPPORTED
            }
        return NativeSttAvailability(
            microphonePermission = permission,
            speechPermission = NativeSttPermission.GRANTED,
            onDeviceAvailable = onDeviceAvailable,
            localeSupported = modelStatus != NativeSttModelStatus.UNSUPPORTED,
            modelStatus = modelStatus,
        )
    }

    override suspend fun prepare(locale: String): NativeSttPreparation {
        ensureActiveAndMainThread()
        val permission = permissionManager.requestIfNeeded()
        AndroidSttPolicy.preparationForPermission(permission)?.let { return it }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
            return NativeSttPreparation(
                NativeSttPreparationStatus.UNSUPPORTED,
                NativeSttFailureCode.ON_DEVICE_UNAVAILABLE,
            )
        }
        return try {
            val cached = modelStatusCache[localeKey(locale)]
            val status =
                if (cached == NativeSttModelStatus.INSTALLED) {
                    cached
                } else {
                    queryModelStatus(locale)
                }
            AndroidSttPolicy.preparationFor(status)
        } catch (error: FlutterError) {
            modelStatusCache.remove(localeKey(locale))
            AndroidSttPolicy.preparationForFailure(
                nativeFailureFromPigeonCode(error.code),
            )
        }
    }

    override suspend fun requestModelDownload(locale: String): NativeSttPreparation {
        ensureActiveAndMainThread()
        if (activeSession != null || pendingStart != null) {
            throw FlutterError("busy", "An STT session is already active.")
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
            return NativeSttPreparation(
                NativeSttPreparationStatus.UNSUPPORTED,
                NativeSttFailureCode.ON_DEVICE_UNAVAILABLE,
            )
        }
        val localeKey = localeKey(locale)
        if (modelDownloadRecognizers.containsKey(localeKey)) {
            return NativeSttPreparation(NativeSttPreparationStatus.MODEL_DOWNLOADING)
        }
        val status = try {
            queryModelStatus(locale)
        } catch (error: FlutterError) {
            modelStatusCache.remove(localeKey)
            return AndroidSttPolicy.preparationForFailure(
                nativeFailureFromPigeonCode(error.code),
            )
        }
        return when (status) {
            NativeSttModelStatus.INSTALLED,
            NativeSttModelStatus.DOWNLOADING,
            NativeSttModelStatus.UNSUPPORTED,
            -> AndroidSttPolicy.preparationFor(status)

            NativeSttModelStatus.SUPPORTED,
            NativeSttModelStatus.MISSING,
            -> {
                val recognizer = createOnDeviceRecognizer()
                modelDownloadRecognizers[localeKey] = recognizer
                try {
                    triggerModelDownload(localeKey, recognizer, recognitionIntent(locale))
                } catch (error: Throwable) {
                    releaseModelDownloadRecognizer(localeKey, recognizer)
                    throw error
                }
                NativeSttPreparation(NativeSttPreparationStatus.MODEL_DOWNLOADING)
            }
        }
    }

    override suspend fun start(request: NativeSttStartRequest) {
        ensureActiveAndMainThread()
        if (activeSession != null || pendingStart != null) {
            throw FlutterError("busy", "An STT session is already active.")
        }
        if (permissionManager.currentPermission() != NativeSttPermission.GRANTED) {
            throw FlutterError("permissionDenied", "Microphone permission is not granted.")
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
            throw FlutterError("onDeviceUnavailable", "On-device STT is unavailable.")
        }

        val reservation = StartReservation(request.sessionId, request.generation)
        pendingStart = reservation
        try {
            val modelStatus =
                modelStatusCache[localeKey(request.locale)] ?: queryModelStatus(request.locale)
            ensurePending(reservation)
            when (modelStatus) {
                NativeSttModelStatus.INSTALLED -> Unit
                NativeSttModelStatus.SUPPORTED,
                NativeSttModelStatus.DOWNLOADING,
                NativeSttModelStatus.MISSING,
                -> throw FlutterError("modelMissing", "The on-device model is not installed.")

                NativeSttModelStatus.UNSUPPORTED ->
                    throw FlutterError("localeUnsupported", "The locale is unsupported.")
            }
            val handle = PlatformSpeechRecognizerHandle(
                createOnDeviceRecognizer(),
                recognitionIntent(request.locale),
            )
            ensurePending(reservation)
            val session = AndroidSpeechSession(
                sessionId = request.sessionId,
                generation = request.generation,
                recognizer = handle,
                eventHandler = ::sendEvent,
                finishedHandler = ::sessionDidFinish,
            )
            activeSession = session
            pendingStart = null
            try {
                session.start()
            } catch (error: Throwable) {
                session.destroy()
                if (activeSession === session) activeSession = null
                throw FlutterError("unknown", "The STT session could not start.")
            }
        } finally {
            if (pendingStart == reservation) pendingStart = null
        }
    }

    override suspend fun cancel(sessionId: String) {
        if (disposed) return
        requireMainThread()
        if (pendingStart?.sessionId == sessionId) pendingStart = null
        val session = activeSession
        if (session?.sessionId == sessionId) session.cancel(emitEvent = true)
    }

    override suspend fun dispose() {
        if (disposed) return
        requireMainThread()
        disposed = true
        pendingStart = null
        activeSession?.cancel(emitEvent = false)
        activeSession = null
        permissionManager.cancelPendingRequest()
        destroySupportRecognizers()
        destroyModelDownloadRecognizers()
        modelStatusCache.clear()
        eventScope.cancel()
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        requireMainThread()
        permissionManager.onRequestPermissionsResult(requestCode, grantResults)
    }

    fun handleBackgroundTransition() {
        if (disposed) return
        requireMainThread()
        pendingStart = null
        activeSession?.cancel(emitEvent = true)
    }

    fun disposeImmediately() {
        if (disposed) return
        requireMainThread()
        disposed = true
        pendingStart = null
        activeSession?.cancel(emitEvent = false)
        activeSession = null
        permissionManager.cancelPendingRequest()
        destroySupportRecognizers()
        destroyModelDownloadRecognizers()
        modelStatusCache.clear()
        eventScope.cancel()
    }

    private suspend fun queryModelStatus(locale: String): NativeSttModelStatus =
        AndroidSttPolicy.modelStatus(locale, queryRecognitionSupport(locale)).also { status ->
            val localeKey = localeKey(locale)
            modelStatusCache[localeKey] = status
            if (AndroidSttPolicy.modelStatusCompletesDownloadRequest(status)) {
                releaseModelDownloadRecognizer(localeKey)
            }
        }

    private fun triggerModelDownload(
        localeKey: String,
        recognizer: SpeechRecognizer,
        intent: Intent,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            recognizer.triggerModelDownload(
                intent,
                activity.mainExecutor,
                object : ModelDownloadListener {
                    override fun onProgress(completedPercent: Int) {
                        applyModelDownloadUpdate(
                            localeKey,
                            recognizer,
                            ModelDownloadCallbackKind.PROGRESS,
                        )
                    }

                    override fun onSuccess() {
                        applyModelDownloadUpdate(
                            localeKey,
                            recognizer,
                            ModelDownloadCallbackKind.SUCCESS,
                        )
                    }

                    override fun onScheduled() {
                        applyModelDownloadUpdate(
                            localeKey,
                            recognizer,
                            ModelDownloadCallbackKind.SCHEDULED,
                        )
                    }

                    override fun onError(error: Int) {
                        applyModelDownloadUpdate(
                            localeKey,
                            recognizer,
                            ModelDownloadCallbackKind.ERROR,
                        )
                    }
                },
            )
            return
        }

        recognizer.triggerModelDownload(intent)
        // API 33 has no delivery callback. Keep the recognizer alive long enough for
        // its asynchronous service connection to forward the request.
        eventScope.launch {
            delay(MODEL_DOWNLOAD_REQUEST_RETENTION_MILLIS)
            releaseModelDownloadRecognizer(localeKey, recognizer)
        }
    }

    private fun applyModelDownloadUpdate(
        localeKey: String,
        recognizer: SpeechRecognizer,
        kind: ModelDownloadCallbackKind,
    ) {
        requireMainThread()
        val update = AndroidSttPolicy.modelDownloadUpdateFor(kind)
        if (!disposed) {
            if (update.status == null) {
                modelStatusCache.remove(localeKey)
            } else {
                modelStatusCache[localeKey] = update.status
            }
        }
        if (update.isTerminal) {
            releaseModelDownloadRecognizer(localeKey, recognizer)
        }
    }

    private suspend fun queryRecognitionSupport(locale: String): RecognitionSupportSnapshot =
        try {
            withTimeout(SUPPORT_CHECK_TIMEOUT_MILLIS) {
                suspendCancellableCoroutine { continuation ->
                    ensureActiveAndMainThread()
                    val recognizer = createOnDeviceRecognizer()
                    supportRecognizers += recognizer
                    continuation.invokeOnCancellation {
                        activity.runOnUiThread { releaseSupportRecognizer(recognizer) }
                    }
                    recognizer.checkRecognitionSupport(
                        recognitionIntent(locale),
                        activity.mainExecutor,
                        object : RecognitionSupportCallback {
                            override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                                releaseSupportRecognizer(recognizer)
                                if (!continuation.isActive) return
                                continuation.resume(
                                    RecognitionSupportSnapshot(
                                        installedLanguages =
                                            recognitionSupport.installedOnDeviceLanguages,
                                        pendingLanguages =
                                            recognitionSupport.pendingOnDeviceLanguages,
                                        supportedLanguages =
                                            recognitionSupport.supportedOnDeviceLanguages,
                                    ),
                                )
                            }

                            override fun onError(error: Int) {
                                releaseSupportRecognizer(recognizer)
                                if (!continuation.isActive) return
                                val failure = AndroidSttPolicy.failureForRecognizerError(error)
                                continuation.resumeWith(
                                    Result.failure(
                                        FlutterError(
                                            code = failure.pigeonCode(),
                                            message = "Recognition support could not be checked.",
                                        ),
                                    ),
                                )
                            }
                        },
                    )
                }
            }
        } catch (_: kotlinx.coroutines.TimeoutCancellationException) {
            throw FlutterError(
                "onDeviceUnavailable",
                "Recognition support check timed out.",
            )
        }

    private fun recognitionIntent(locale: String) =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                putExtra(
                    RecognizerIntent.EXTRA_ENABLE_FORMATTING,
                    RecognizerIntent.FORMATTING_OPTIMIZE_LATENCY,
                )
                putExtra(RecognizerIntent.EXTRA_HIDE_PARTIAL_TRAILING_PUNCTUATION, true)
            }
        }

    private fun createOnDeviceRecognizer(): SpeechRecognizer {
        requireMainThread()
        return try {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        } catch (error: UnsupportedOperationException) {
            throw FlutterError("onDeviceUnavailable", "On-device STT is unavailable.")
        }
    }

    private fun releaseSupportRecognizer(recognizer: SpeechRecognizer) {
        requireMainThread()
        if (supportRecognizers.remove(recognizer)) recognizer.destroy()
    }

    private fun destroySupportRecognizers() {
        requireMainThread()
        val recognizers = supportRecognizers.toList()
        supportRecognizers.clear()
        recognizers.forEach(SpeechRecognizer::destroy)
    }

    private fun releaseModelDownloadRecognizer(
        localeKey: String,
        expected: SpeechRecognizer? = null,
    ) {
        requireMainThread()
        val recognizer = modelDownloadRecognizers[localeKey] ?: return
        if (expected != null && recognizer !== expected) return
        modelDownloadRecognizers.remove(localeKey)
        recognizer.destroy()
    }

    private fun destroyModelDownloadRecognizers() {
        requireMainThread()
        val recognizers = modelDownloadRecognizers.values.toList()
        modelDownloadRecognizers.clear()
        recognizers.forEach(SpeechRecognizer::destroy)
    }

    private fun sendEvent(event: NativeSttEvent) {
        val session = activeSession
        if (disposed || session?.matches(event) != true) return
        eventScope.launch {
            runCatching { flutterApi.onEvent(event) }
        }
    }

    private fun sessionDidFinish(session: AndroidSpeechSession) {
        if (activeSession === session) activeSession = null
    }

    private fun ensurePending(reservation: StartReservation) {
        if (pendingStart != reservation) {
            throw FlutterError("cancelled", "The STT start was cancelled.")
        }
    }

    private fun ensureActiveAndMainThread() {
        if (disposed) throw FlutterError("cancelled", "The STT adapter is disposed.")
        requireMainThread()
    }

    private fun localeKey(locale: String): String =
        Locale.forLanguageTag(locale).toLanguageTag().lowercase(Locale.ROOT)

    private fun requireMainThread() {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "SpeechRecognizer must be accessed on the Android main looper."
        }
    }

    private companion object {
        const val SUPPORT_CHECK_TIMEOUT_MILLIS = 10_000L
        const val MODEL_DOWNLOAD_REQUEST_RETENTION_MILLIS = 30_000L
    }
}

private class RecordAudioPermissionManager(
    private val activity: Activity,
) {
    private val preferences =
        activity.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    private var pendingRequest: CancellableContinuation<NativeSttPermission>? = null

    fun currentPermission(): NativeSttPermission =
        when {
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED -> NativeSttPermission.GRANTED

            preferences.getBoolean(KEY_PERMISSION_REQUESTED, false) -> NativeSttPermission.DENIED
            else -> NativeSttPermission.NOT_DETERMINED
        }

    suspend fun requestIfNeeded(): NativeSttPermission {
        val current = currentPermission()
        if (current != NativeSttPermission.NOT_DETERMINED) return current
        if (pendingRequest != null) {
            throw FlutterError("busy", "A microphone permission request is already active.")
        }
        return suspendCancellableCoroutine { continuation ->
            pendingRequest = continuation
            continuation.invokeOnCancellation {
                if (pendingRequest === continuation) pendingRequest = null
            }
            preferences.edit().putBoolean(KEY_PERMISSION_REQUESTED, true).apply()
            activity.requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                RECORD_AUDIO_REQUEST_CODE,
            )
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != RECORD_AUDIO_REQUEST_CODE) return
        val continuation = pendingRequest ?: return
        pendingRequest = null
        if (!continuation.isActive) return
        continuation.resume(
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                NativeSttPermission.GRANTED
            } else {
                NativeSttPermission.DENIED
            },
        )
    }

    fun cancelPendingRequest() {
        pendingRequest?.cancel()
        pendingRequest = null
    }

    private companion object {
        const val PREFERENCES_NAME = "stt_permission_state"
        const val KEY_PERMISSION_REQUESTED = "record_audio_requested"
        const val RECORD_AUDIO_REQUEST_CODE = 2701
    }
}

private fun NativeSttFailureCode.pigeonCode(): String =
    when (this) {
        NativeSttFailureCode.PERMISSION_DENIED -> "permissionDenied"
        NativeSttFailureCode.ON_DEVICE_UNAVAILABLE -> "onDeviceUnavailable"
        NativeSttFailureCode.LOCALE_UNSUPPORTED -> "localeUnsupported"
        NativeSttFailureCode.MODEL_MISSING -> "modelMissing"
        NativeSttFailureCode.BUSY -> "busy"
        NativeSttFailureCode.NO_MATCH -> "noMatch"
        NativeSttFailureCode.AUDIO -> "audio"
        NativeSttFailureCode.AUDIO_FORMAT_MISMATCH -> "audioFormatMismatch"
        NativeSttFailureCode.INTERRUPTED -> "interrupted"
        NativeSttFailureCode.CANCELLED -> "cancelled"
        NativeSttFailureCode.UNKNOWN -> "unknown"
    }

private fun nativeFailureFromPigeonCode(code: String): NativeSttFailureCode =
    when (code) {
        "permissionDenied" -> NativeSttFailureCode.PERMISSION_DENIED
        "onDeviceUnavailable" -> NativeSttFailureCode.ON_DEVICE_UNAVAILABLE
        "localeUnsupported" -> NativeSttFailureCode.LOCALE_UNSUPPORTED
        "modelMissing" -> NativeSttFailureCode.MODEL_MISSING
        "busy" -> NativeSttFailureCode.BUSY
        "noMatch" -> NativeSttFailureCode.NO_MATCH
        "audio" -> NativeSttFailureCode.AUDIO
        "audioFormatMismatch" -> NativeSttFailureCode.AUDIO_FORMAT_MISMATCH
        "interrupted" -> NativeSttFailureCode.INTERRUPTED
        "cancelled" -> NativeSttFailureCode.CANCELLED
        else -> NativeSttFailureCode.UNKNOWN
    }
