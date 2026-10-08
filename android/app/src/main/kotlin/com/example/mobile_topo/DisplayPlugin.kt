package com.example.mobile_topo

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reports the physical size of Flutter's logical pixels, so drawings can be
 * shown at a true map scale.
 *
 * Mirrors the "mobile_topo/display" channel handled in
 * macos/Runner/AppDelegate.swift.
 */
class DisplayPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private companion object {
        const val MM_PER_INCH = 25.4
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "mobile_topo/display").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "logicalPixelsPerMm" -> result.success(logicalPixelsPerMm())
            else -> result.notImplemented()
        }
    }

    /**
     * Flutter logical pixels (Android dp) per millimetre, or null if unknown.
     *
     * xdpi/ydpi are the screen's measured physical pixels per inch. A few
     * devices report nonsense there, so the nominal density bucket is used
     * instead when the two disagree by more than a factor of two.
     */
    private fun logicalPixelsPerMm(): Double? {
        val metrics = context?.resources?.displayMetrics ?: return null
        val measured = (metrics.xdpi + metrics.ydpi) / 2.0
        val nominal = metrics.densityDpi.toDouble()
        val pixelsPerInch =
            if (measured > 0 && measured / nominal in 0.5..2.0) measured else nominal
        // Flutter's device pixel ratio on Android is metrics.density
        return pixelsPerInch / metrics.density / MM_PER_INCH
    }
}
