package com.marcorable.maltto

import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.ParcelFileDescriptor
import android.speech.RecognizerIntent
import android.util.Log
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
import kotlin.math.max

internal interface RecognitionAudioSource {
    fun configure(intent: Intent)

    fun start()

    fun close()
}

internal class AndroidRecognitionAudioSource private constructor(
    private val audioRecord: AudioRecord,
    private val recognizerDescriptor: ParcelFileDescriptor,
    private val writerDescriptor: ParcelFileDescriptor,
    private val bufferSize: Int,
) : RecognitionAudioSource {
    private val started = AtomicBoolean(false)
    private val closed = AtomicBoolean(false)
    private var writerThread: Thread? = null

    override fun configure(intent: Intent) {
        check(!closed.get())
        intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, recognizerDescriptor)
        intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, CHANNEL_COUNT)
        intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, ENCODING)
        intent.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, SAMPLE_RATE_HZ)
        intent.putExtra(
            RecognizerIntent.EXTRA_SEGMENTED_SESSION,
            RecognizerIntent.EXTRA_AUDIO_SOURCE,
        )
    }

    override fun start() {
        check(!closed.get())
        if (!started.compareAndSet(false, true)) return

        audioRecord.startRecording()
        check(audioRecord.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
            "Microphone recording did not start."
        }
        writerThread = thread(name = WRITER_THREAD_NAME, isDaemon = true) {
            pumpAudio()
        }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        if (audioRecord.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
            runCatching { audioRecord.stop() }
        }
        runCatching { writerDescriptor.close() }
        writerThread?.interrupt()
        runCatching { audioRecord.release() }
        runCatching { recognizerDescriptor.close() }
    }

    private fun pumpAudio() {
        val buffer = ByteArray(bufferSize)
        try {
            ParcelFileDescriptor.AutoCloseOutputStream(writerDescriptor).use { output ->
                while (!closed.get()) {
                    val count = audioRecord.read(
                        buffer,
                        0,
                        buffer.size,
                        AudioRecord.READ_BLOCKING,
                    )
                    when {
                        count > 0 -> output.write(buffer, 0, count)
                        count == AudioRecord.ERROR_DEAD_OBJECT -> return
                        count < 0 -> throw IOException("AudioRecord read failed with $count")
                    }
                }
            }
        } catch (error: IOException) {
            if (!closed.get()) {
                Log.w(DIAGNOSTIC_TAG, "microphone stream ended unexpectedly", error)
            }
        }
    }

    companion object {
        private const val SAMPLE_RATE_HZ = 16_000
        private const val CHANNEL_COUNT = 1
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val MINIMUM_BUFFER_MILLIS = 100
        private const val BYTES_PER_SAMPLE = 2
        private const val WRITER_THREAD_NAME = "MalttoSttAudio"
        private const val DIAGNOSTIC_TAG = "MalttoSttFlow"

        fun create(): AndroidRecognitionAudioSource {
            val minimumBuffer = AudioRecord.getMinBufferSize(
                SAMPLE_RATE_HZ,
                AudioFormat.CHANNEL_IN_MONO,
                ENCODING,
            )
            check(minimumBuffer > 0) { "No supported microphone buffer size." }
            val durationBuffer =
                SAMPLE_RATE_HZ * BYTES_PER_SAMPLE * MINIMUM_BUFFER_MILLIS / 1_000
            val bufferSize = max(minimumBuffer, durationBuffer)
            val audioRecord = AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(ENCODING)
                        .setSampleRate(SAMPLE_RATE_HZ)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(bufferSize)
                .build()
            check(audioRecord.state == AudioRecord.STATE_INITIALIZED) {
                audioRecord.release()
                "Microphone could not be initialized."
            }
            return try {
                val descriptors = ParcelFileDescriptor.createPipe()
                AndroidRecognitionAudioSource(
                    audioRecord = audioRecord,
                    recognizerDescriptor = descriptors[0],
                    writerDescriptor = descriptors[1],
                    bufferSize = bufferSize,
                )
            } catch (error: Throwable) {
                audioRecord.release()
                throw error
            }
        }
    }
}
