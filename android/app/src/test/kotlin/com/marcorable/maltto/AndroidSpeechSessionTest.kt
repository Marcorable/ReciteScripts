package com.marcorable.maltto

import android.speech.RecognitionListener
import android.speech.SpeechRecognizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidSpeechSessionTest {
    @Test
    fun `ready partial final and ended share generation with increasing sequence`() {
        val recognizer = FakeSpeechRecognizerHandle()
        val events = mutableListOf<NativeSttEvent>()
        val session = session(recognizer, events)

        session.start()
        session.onReadyForSpeech(null)
        session.emitPartialForTest("  직접 만든 문장  ")
        session.finishWithResult("마지막 결과")

        assertTrue(recognizer.started)
        assertEquals(
            listOf(
                NativeSttEventKind.READY,
                NativeSttEventKind.PARTIAL,
                NativeSttEventKind.FINAL_RESULT,
                NativeSttEventKind.ENDED,
            ),
            events.map { it.kind },
        )
        assertEquals(listOf(1L, 2L, 3L, 4L), events.map { it.sequence })
        assertTrue(events.all { it.sessionId == "session" && it.generation == 7L })
        assertEquals("직접 만든 문장", events[1].text)
        assertTrue(recognizer.destroyed)
    }

    @Test
    fun `cancel emits once and ignores late callbacks`() {
        val recognizer = FakeSpeechRecognizerHandle()
        val events = mutableListOf<NativeSttEvent>()
        val session = session(recognizer, events)

        session.cancel(emitEvent = true)
        session.onReadyForSpeech(null)
        session.emitPartialForTest("늦은 결과")
        session.finishWithResult("늦은 최종 결과")
        session.onError(SpeechRecognizer.ERROR_NO_MATCH)

        assertEquals(listOf(NativeSttEventKind.CANCELLED), events.map { it.kind })
        assertTrue(recognizer.cancelled)
        assertTrue(recognizer.destroyed)
    }

    @Test
    fun `empty final and recognition error become structured failures`() {
        val emptyEvents = mutableListOf<NativeSttEvent>()
        session(FakeSpeechRecognizerHandle(), emptyEvents).finishWithResult("   ")

        assertEquals(NativeSttEventKind.FAILURE, emptyEvents.single().kind)
        assertEquals(NativeSttFailureCode.NO_MATCH, emptyEvents.single().failureCode)
        assertEquals(true, emptyEvents.single().retryable)

        val deniedEvents = mutableListOf<NativeSttEvent>()
        session(FakeSpeechRecognizerHandle(), deniedEvents).onError(
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
        )

        assertEquals(NativeSttFailureCode.PERMISSION_DENIED, deniedEvents.single().failureCode)
        assertEquals(false, deniedEvents.single().retryable)
    }

    private fun session(
        recognizer: FakeSpeechRecognizerHandle,
        events: MutableList<NativeSttEvent>,
    ): AndroidSpeechSession =
        AndroidSpeechSession(
            sessionId = "session",
            generation = 7,
            recognizer = recognizer,
            eventHandler = events::add,
            finishedHandler = {},
        )
}

private class FakeSpeechRecognizerHandle : SpeechRecognizerHandle {
    var listener: RecognitionListener? = null
    var started = false
    var cancelled = false
    var destroyed = false

    override fun setRecognitionListener(listener: RecognitionListener?) {
        this.listener = listener
    }

    override fun startListening() {
        started = true
    }

    override fun cancel() {
        cancelled = true
    }

    override fun destroy() {
        destroyed = true
    }
}
