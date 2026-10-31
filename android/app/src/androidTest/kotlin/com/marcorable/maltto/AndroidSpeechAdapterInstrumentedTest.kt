package com.marcorable.maltto

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class AndroidSpeechAdapterInstrumentedTest {
    @Test
    fun availabilityPreparationAndBackgroundCleanupRemainStructured() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val permissionGranted =
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED

        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var adapter: AndroidSpeechAdapter
            scenario.onActivity { activity ->
                adapter = activity.speechAdapterForTesting()
            }
            val availability = awaitAdapterCall {
                adapter.checkAvailability(TEST_LOCALE)
            }
            Log.i(
                DIAGNOSTIC_TAG,
                "STT_DIAGNOSTIC onDevice=${availability.onDeviceAvailable} " +
                    "locale=${availability.localeSupported} model=${availability.modelStatus} " +
                    "permission=${availability.microphonePermission}",
            )

            assertEquals(
                permissionGranted,
                availability.microphonePermission == NativeSttPermission.GRANTED,
            )
            assertEquals(NativeSttPermission.GRANTED, availability.speechPermission)
            if (!availability.onDeviceAvailable) {
                assertFalse(availability.localeSupported)
                assertEquals(NativeSttModelStatus.UNSUPPORTED, availability.modelStatus)
                return@use
            }

            assertEquals(
                availability.modelStatus != NativeSttModelStatus.UNSUPPORTED,
                availability.localeSupported,
            )
            if (!permissionGranted) return@use

            val preparation = awaitAdapterCall { adapter.prepare(TEST_LOCALE) }
            Log.i(DIAGNOSTIC_TAG, "STT_DIAGNOSTIC preparation=${preparation.status}")
            assertEquals(
                expectedPreparation(availability.modelStatus),
                preparation.status,
            )
            if (preparation.status == NativeSttPreparationStatus.READY) {
                awaitAdapterCall {
                    adapter.start(
                        NativeSttStartRequest(
                            sessionId = "instrumented-session",
                            generation = 1,
                            locale = TEST_LOCALE,
                        ),
                    )
                }
                scenario.onActivity {
                    adapter.handleBackgroundTransition()
                }
            }
        }
    }

    @Test
    fun airplaneModeKoreanRecognitionEmitsTextWhenExplicitlyRequested() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(arguments.getString("liveStt") == "true")
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        assertEquals(1, Settings.Global.getInt(context.contentResolver, "airplane_mode_on", 0))
        assertEquals(
            PackageManager.PERMISSION_GRANTED,
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO),
        )

        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var activity: MainActivity
            scenario.onActivity { activity = it }
            val events = LinkedBlockingQueue<NativeSttEvent>()
            lateinit var session: AndroidSpeechSession
            awaitAdapterCall {
                val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
                session = AndroidSpeechSession(
                    sessionId = "live-instrumented-session",
                    generation = 1,
                    recognizer = PlatformSpeechRecognizerHandle(
                        recognizer,
                        liveRecognitionIntent(),
                    ),
                    eventHandler = events::offer,
                    finishedHandler = {},
                )
                session.start()
            }

            try {
                var textEvent: NativeSttEvent? = null
                val deadlineNanos = System.nanoTime() + TimeUnit.SECONDS.toNanos(20)
                while (System.nanoTime() < deadlineNanos && textEvent == null) {
                    val event = events.poll(1, TimeUnit.SECONDS) ?: continue
                    if (event.kind == NativeSttEventKind.PARTIAL ||
                        event.kind == NativeSttEventKind.FINAL_RESULT
                    ) {
                        textEvent = event
                    } else if (event.kind == NativeSttEventKind.FAILURE) {
                        throw AssertionError("Recognition failed with ${event.failureCode}")
                    }
                }
                assertNotNull("No partial or final ko-KR result was received.", textEvent)
                Log.i(DIAGNOSTIC_TAG, "STT_DIAGNOSTIC airplaneModeTextEvent=${textEvent?.kind}")
            } finally {
                scenario.onActivity { session.cancel(emitEvent = false) }
            }
        }
    }

    private fun expectedPreparation(status: NativeSttModelStatus): NativeSttPreparationStatus =
        when (status) {
            NativeSttModelStatus.INSTALLED -> NativeSttPreparationStatus.READY
            NativeSttModelStatus.DOWNLOADING -> NativeSttPreparationStatus.MODEL_DOWNLOADING
            NativeSttModelStatus.SUPPORTED,
            NativeSttModelStatus.MISSING,
            -> NativeSttPreparationStatus.MODEL_DOWNLOAD_REQUIRED

            NativeSttModelStatus.UNSUPPORTED -> NativeSttPreparationStatus.UNSUPPORTED
        }

    private fun <T> awaitAdapterCall(block: suspend () -> T): T {
        val result = CompletableDeferred<Result<T>>()
        CoroutineScope(Dispatchers.Main.immediate).launch {
            result.complete(runCatching { block() })
        }
        return runBlocking {
            withTimeout(20_000) { result.await().getOrThrow() }
        }
    }

    private fun liveRecognitionIntent() =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, TEST_LOCALE)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

    private companion object {
        const val TEST_LOCALE = "ko-KR"
        const val DIAGNOSTIC_TAG = "MalttoSttTest"
    }
}
