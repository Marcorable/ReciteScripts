package com.marcorable.maltto

import android.speech.SpeechRecognizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidSttPolicyTest {
    @Test
    fun `permission states remain structured`() {
        assertNull(AndroidSttPolicy.preparationForPermission(NativeSttPermission.GRANTED))
        assertEquals(
            NativeSttPreparationStatus.PERMISSION_REQUIRED,
            AndroidSttPolicy
                .preparationForPermission(NativeSttPermission.NOT_DETERMINED)
                ?.status,
        )
        assertEquals(
            NativeSttPreparationStatus.PERMISSION_DENIED,
            AndroidSttPolicy.preparationForPermission(NativeSttPermission.DENIED)?.status,
        )
    }

    @Test
    fun `ko-KR support distinguishes installed pending downloadable and unsupported`() {
        fun status(
            installed: List<String> = emptyList(),
            pending: List<String> = emptyList(),
            supported: List<String> = emptyList(),
        ) = AndroidSttPolicy.modelStatus(
            "ko-KR",
            RecognitionSupportSnapshot(installed, pending, supported),
        )

        assertEquals(NativeSttModelStatus.INSTALLED, status(installed = listOf("ko-KR")))
        assertEquals(NativeSttModelStatus.DOWNLOADING, status(pending = listOf("ko-KR")))
        assertEquals(NativeSttModelStatus.SUPPORTED, status(supported = listOf("ko-KR")))
        assertEquals(NativeSttModelStatus.UNSUPPORTED, status(supported = listOf("en-US")))
    }

    @Test
    fun `model preparation never starts a hidden download`() {
        val missing = AndroidSttPolicy.preparationFor(NativeSttModelStatus.SUPPORTED)
        val downloading = AndroidSttPolicy.preparationFor(NativeSttModelStatus.DOWNLOADING)

        assertEquals(NativeSttPreparationStatus.MODEL_DOWNLOAD_REQUIRED, missing.status)
        assertEquals(NativeSttFailureCode.MODEL_MISSING, missing.failureCode)
        assertEquals(NativeSttPreparationStatus.MODEL_DOWNLOADING, downloading.status)
    }

    @Test
    fun `recognizer errors map to platform neutral failures`() {
        assertEquals(
            NativeSttFailureCode.PERMISSION_DENIED,
            AndroidSttPolicy.failureForRecognizerError(
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
            ),
        )
        assertEquals(
            NativeSttFailureCode.MODEL_MISSING,
            AndroidSttPolicy.failureForRecognizerError(
                SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
            ),
        )
        assertEquals(
            NativeSttFailureCode.NO_MATCH,
            AndroidSttPolicy.failureForRecognizerError(SpeechRecognizer.ERROR_NO_MATCH),
        )
        assertTrue(AndroidSttPolicy.isRetryable(NativeSttFailureCode.NO_MATCH))
        assertFalse(AndroidSttPolicy.isRetryable(NativeSttFailureCode.PERMISSION_DENIED))
    }
}
