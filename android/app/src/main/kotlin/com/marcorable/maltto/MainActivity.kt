package com.marcorable.maltto

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var speechAdapter: AndroidSpeechAdapter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val adapter = AndroidSpeechAdapter(this, flutterEngine.dartExecutor.binaryMessenger)
        NativeSttHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, adapter)
        speechAdapter = adapter
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        speechAdapter?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onStop() {
        speechAdapter?.handleBackgroundTransition()
        super.onStop()
    }

    override fun onDestroy() {
        speechAdapter?.disposeImmediately()
        speechAdapter = null
        super.onDestroy()
    }

    internal fun speechAdapterForTesting(): AndroidSpeechAdapter = checkNotNull(speechAdapter)
}
