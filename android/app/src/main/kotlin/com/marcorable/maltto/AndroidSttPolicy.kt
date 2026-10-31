package com.marcorable.maltto

import android.speech.SpeechRecognizer
import java.util.Locale

internal data class RecognitionSupportSnapshot(
    val installedLanguages: List<String>,
    val pendingLanguages: List<String>,
    val supportedLanguages: List<String>,
)

internal enum class ModelDownloadCallbackKind {
    PROGRESS,
    SUCCESS,
    SCHEDULED,
    ERROR,
}

internal data class ModelDownloadUpdate(
    val status: NativeSttModelStatus?,
    val isTerminal: Boolean,
)

internal object AndroidSttPolicy {
    fun preparationForPermission(permission: NativeSttPermission): NativeSttPreparation? =
        when (permission) {
            NativeSttPermission.GRANTED -> null
            NativeSttPermission.NOT_DETERMINED -> NativeSttPreparation(
                NativeSttPreparationStatus.PERMISSION_REQUIRED,
                NativeSttFailureCode.PERMISSION_DENIED,
            )

            NativeSttPermission.DENIED,
            NativeSttPermission.RESTRICTED,
            -> NativeSttPreparation(
                NativeSttPreparationStatus.PERMISSION_DENIED,
                NativeSttFailureCode.PERMISSION_DENIED,
            )
        }

    fun modelStatus(
        locale: String,
        support: RecognitionSupportSnapshot,
    ): NativeSttModelStatus =
        when {
            support.installedLanguages.matches(locale) -> NativeSttModelStatus.INSTALLED
            support.pendingLanguages.matches(locale) -> NativeSttModelStatus.DOWNLOADING
            support.supportedLanguages.matches(locale) -> NativeSttModelStatus.SUPPORTED
            else -> NativeSttModelStatus.UNSUPPORTED
        }

    fun preparationFor(status: NativeSttModelStatus): NativeSttPreparation =
        when (status) {
            NativeSttModelStatus.INSTALLED ->
                NativeSttPreparation(NativeSttPreparationStatus.READY)

            NativeSttModelStatus.DOWNLOADING ->
                NativeSttPreparation(NativeSttPreparationStatus.MODEL_DOWNLOADING)

            NativeSttModelStatus.SUPPORTED,
            NativeSttModelStatus.MISSING,
            -> NativeSttPreparation(
                NativeSttPreparationStatus.MODEL_DOWNLOAD_REQUIRED,
                NativeSttFailureCode.MODEL_MISSING,
            )

            NativeSttModelStatus.UNSUPPORTED -> NativeSttPreparation(
                NativeSttPreparationStatus.UNSUPPORTED,
                NativeSttFailureCode.LOCALE_UNSUPPORTED,
            )
        }

    fun preparationForFailure(failure: NativeSttFailureCode): NativeSttPreparation =
        NativeSttPreparation(
            status =
                if (failure == NativeSttFailureCode.MODEL_MISSING) {
                    NativeSttPreparationStatus.MODEL_DOWNLOAD_REQUIRED
                } else {
                    NativeSttPreparationStatus.UNSUPPORTED
                },
            failureCode = failure,
        )

    fun modelDownloadUpdateFor(kind: ModelDownloadCallbackKind): ModelDownloadUpdate =
        when (kind) {
            ModelDownloadCallbackKind.PROGRESS -> ModelDownloadUpdate(
                status = NativeSttModelStatus.DOWNLOADING,
                isTerminal = false,
            )

            ModelDownloadCallbackKind.SUCCESS -> ModelDownloadUpdate(
                status = NativeSttModelStatus.INSTALLED,
                isTerminal = true,
            )

            ModelDownloadCallbackKind.SCHEDULED -> ModelDownloadUpdate(
                status = NativeSttModelStatus.DOWNLOADING,
                isTerminal = true,
            )

            ModelDownloadCallbackKind.ERROR -> ModelDownloadUpdate(
                status = null,
                isTerminal = true,
            )
        }

    fun modelStatusCompletesDownloadRequest(status: NativeSttModelStatus): Boolean =
        status == NativeSttModelStatus.INSTALLED ||
            status == NativeSttModelStatus.UNSUPPORTED

    fun failureForRecognizerError(error: Int): NativeSttFailureCode =
        when (error) {
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                NativeSttFailureCode.PERMISSION_DENIED

            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ->
                NativeSttFailureCode.LOCALE_UNSUPPORTED

            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
                NativeSttFailureCode.MODEL_MISSING

            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> NativeSttFailureCode.BUSY
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
            -> NativeSttFailureCode.NO_MATCH

            SpeechRecognizer.ERROR_AUDIO -> NativeSttFailureCode.AUDIO
            SpeechRecognizer.ERROR_CLIENT -> NativeSttFailureCode.INTERRUPTED
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
            SpeechRecognizer.ERROR_SERVER,
            SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
            -> NativeSttFailureCode.ON_DEVICE_UNAVAILABLE

            else -> NativeSttFailureCode.UNKNOWN
        }

    fun isRetryable(code: NativeSttFailureCode): Boolean =
        when (code) {
            NativeSttFailureCode.BUSY,
            NativeSttFailureCode.NO_MATCH,
            NativeSttFailureCode.AUDIO,
            NativeSttFailureCode.INTERRUPTED,
            NativeSttFailureCode.UNKNOWN,
            -> true

            else -> false
        }

    private fun List<String>.matches(requestedLocale: String): Boolean {
        val requested = Locale.forLanguageTag(requestedLocale).toLanguageTag()
        return any { Locale.forLanguageTag(it).toLanguageTag().equals(requested, ignoreCase = true) }
    }
}
