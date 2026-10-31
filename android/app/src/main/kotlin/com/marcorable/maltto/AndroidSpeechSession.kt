package com.marcorable.maltto

import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.SpeechRecognizer

internal interface SpeechRecognizerHandle {
    fun setRecognitionListener(listener: RecognitionListener?)

    fun startListening()

    fun cancel()

    fun destroy()
}

internal class PlatformSpeechRecognizerHandle(
    private val recognizer: SpeechRecognizer,
    private val recognitionIntent: android.content.Intent,
) : SpeechRecognizerHandle {
    override fun setRecognitionListener(listener: RecognitionListener?) {
        recognizer.setRecognitionListener(listener)
    }

    override fun startListening() {
        recognizer.startListening(recognitionIntent)
    }

    override fun cancel() {
        recognizer.cancel()
    }

    override fun destroy() {
        recognizer.destroy()
    }
}

internal class AndroidSpeechSession(
    val sessionId: String,
    val generation: Long,
    private val recognizer: SpeechRecognizerHandle,
    private val eventHandler: (NativeSttEvent) -> Unit,
    private val finishedHandler: (AndroidSpeechSession) -> Unit,
) : RecognitionListener {
    private var sequence = 0L
    private var acceptsEvents = true
    private var destroyed = false

    init {
        recognizer.setRecognitionListener(this)
    }

    fun start() {
        check(acceptsEvents)
        recognizer.startListening()
    }

    fun matches(event: NativeSttEvent): Boolean =
        event.sessionId == sessionId && event.generation == generation

    fun cancel(emitEvent: Boolean) {
        if (!acceptsEvents) return
        acceptsEvents = false
        recognizer.cancel()
        if (emitEvent) emitUnchecked(NativeSttEventKind.CANCELLED)
        cleanUp()
        finishedHandler(this)
    }

    fun destroy() {
        acceptsEvents = false
        cleanUp()
    }

    override fun onReadyForSpeech(params: Bundle?) {
        emit(NativeSttEventKind.READY)
    }

    override fun onBeginningOfSpeech() = Unit

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() = Unit

    override fun onError(error: Int) {
        if (!acceptsEvents) return
        val code = AndroidSttPolicy.failureForRecognizerError(error)
        acceptsEvents = false
        emitUnchecked(
            NativeSttEventKind.FAILURE,
            failureCode = code,
            retryable = AndroidSttPolicy.isRetryable(code),
        )
        cleanUp()
        finishedHandler(this)
    }

    override fun onPartialResults(partialResults: Bundle?) {
        emitText(NativeSttEventKind.PARTIAL, resultText(partialResults))
    }

    override fun onResults(results: Bundle?) {
        finishWithResult(resultText(results))
    }

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    internal fun emitPartialForTest(text: String?) {
        emitText(NativeSttEventKind.PARTIAL, text)
    }

    internal fun finishWithResult(text: String?) {
        if (!acceptsEvents) return
        val trimmed = text?.trim().orEmpty()
        acceptsEvents = false
        if (trimmed.isEmpty()) {
            emitUnchecked(
                NativeSttEventKind.FAILURE,
                failureCode = NativeSttFailureCode.NO_MATCH,
                retryable = true,
            )
        } else {
            emitUnchecked(NativeSttEventKind.FINAL_RESULT, text = trimmed)
            emitUnchecked(NativeSttEventKind.ENDED)
        }
        cleanUp()
        finishedHandler(this)
    }

    private fun resultText(results: Bundle?): String? =
        results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()

    private fun emitText(kind: NativeSttEventKind, text: String?) {
        val trimmed = text?.trim().orEmpty()
        if (trimmed.isEmpty()) return
        emit(kind, text = trimmed)
    }

    private fun emit(
        kind: NativeSttEventKind,
        text: String? = null,
        failureCode: NativeSttFailureCode? = null,
        retryable: Boolean? = null,
    ) {
        if (!acceptsEvents) return
        emitUnchecked(kind, text, failureCode, retryable)
    }

    private fun emitUnchecked(
        kind: NativeSttEventKind,
        text: String? = null,
        failureCode: NativeSttFailureCode? = null,
        retryable: Boolean? = null,
    ) {
        sequence += 1
        eventHandler(
            NativeSttEvent(
                sessionId = sessionId,
                generation = generation,
                sequence = sequence,
                kind = kind,
                text = text,
                failureCode = failureCode,
                retryable = retryable,
            ),
        )
    }

    private fun cleanUp() {
        if (destroyed) return
        destroyed = true
        recognizer.setRecognitionListener(null)
        recognizer.destroy()
    }
}
