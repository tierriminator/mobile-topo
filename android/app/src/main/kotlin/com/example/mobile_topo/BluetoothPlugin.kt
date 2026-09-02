package com.example.mobile_topo

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

/**
 * Flutter plugin for Classic Bluetooth SPP on Android.
 *
 * Mirrors the channel contract of macos/Runner/BluetoothPlugin.swift so a single
 * Dart-side [BluetoothChannel] can drive both platforms. The DistoX is a Classic
 * Bluetooth (RFCOMM) device, so BLE APIs are deliberately not used here.
 */
class BluetoothPlugin :
    FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private companion object {
        const val TAG = "BluetoothPlugin"

        /** Standard Serial Port Profile UUID. */
        val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        const val REQUEST_PERMISSIONS = 4711
        const val REQUEST_ENABLE_BLUETOOTH = 4712

        /** Native connect timeout; the Dart side applies a slightly longer one. */
        const val CONNECT_TIMEOUT_MS = 5000L
    }

    private var methodChannel: MethodChannel? = null
    private var dataChannel: EventChannel? = null
    private var stateChannel: EventChannel? = null

    private var dataSink: EventChannel.EventSink? = null
    private var stateSink: EventChannel.EventSink? = null

    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var socket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null
    private var readThread: Thread? = null

    private var discoveryReceiver: BroadcastReceiver? = null

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingEnableResult: MethodChannel.Result? = null

    private val main = Handler(Looper.getMainLooper())

    private val bluetoothAdapter: BluetoothAdapter?
        get() {
            val context = applicationContext ?: return null
            val manager =
                context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            return manager?.adapter
        }

    // MARK: - FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "mobile_topo/bluetooth").also {
            it.setMethodCallHandler(this)
        }

        dataChannel = EventChannel(binding.binaryMessenger, "mobile_topo/bluetooth/data").also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    dataSink = events
                }

                override fun onCancel(arguments: Any?) {
                    dataSink = null
                }
            })
        }

        stateChannel = EventChannel(binding.binaryMessenger, "mobile_topo/bluetooth/state").also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    stateSink = events
                }

                override fun onCancel(arguments: Any?) {
                    stateSink = null
                }
            })
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        disconnect()
        stopDiscovery()

        methodChannel?.setMethodCallHandler(null)
        dataChannel?.setStreamHandler(null)
        stateChannel?.setStreamHandler(null)

        methodChannel = null
        dataChannel = null
        stateChannel = null
        applicationContext = null
    }

    // MARK: - ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(permissionsListener)
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(permissionsListener)
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
        activity = null
    }

    // MARK: - MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(bluetoothAdapter != null)

            "isPoweredOn" -> result.success(bluetoothAdapter?.isEnabled == true)

            "requestEnable" -> requestEnable(result)

            "ensurePermissions" -> ensurePermissions(result)

            "getPairedDevices" -> getPairedDevices(result)

            "startDiscovery" -> {
                startDiscovery()
                result.success(null)
            }

            "stopDiscovery" -> {
                stopDiscovery()
                result.success(null)
            }

            "connect" -> {
                val address = call.argument<String>("address")
                if (address == null) {
                    result.error("INVALID_ARGS", "Missing address", null)
                } else {
                    connect(address, result)
                }
            }

            "disconnect" -> {
                disconnect()
                result.success(null)
            }

            "send" -> {
                val data = call.argument<ByteArray>("data")
                if (data == null) {
                    result.error("INVALID_ARGS", "Missing data", null)
                } else {
                    result.success(send(data))
                }
            }

            else -> result.notImplemented()
        }
    }

    // MARK: - Permissions

    /**
     * Permissions needed to scan for and connect to a Classic Bluetooth device.
     *
     * Android 12 (API 31) replaced the install-time BLUETOOTH/BLUETOOTH_ADMIN
     * permissions with runtime BLUETOOTH_SCAN/BLUETOOTH_CONNECT. Below 31,
     * discovery requires a location permission instead.
     */
    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun hasPermissions(): Boolean {
        val context = applicationContext ?: return false
        return requiredPermissions().all {
            context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun ensurePermissions(result: MethodChannel.Result) {
        if (hasPermissions()) {
            result.success(true)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.success(false)
            return
        }

        if (pendingPermissionResult != null) {
            result.error("BUSY", "A permission request is already in flight", null)
            return
        }

        pendingPermissionResult = result
        currentActivity.requestPermissions(requiredPermissions(), REQUEST_PERMISSIONS)
    }

    private val permissionsListener =
        io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener {
            requestCode, _, grantResults ->
            if (requestCode != REQUEST_PERMISSIONS) {
                false
            } else {
                val granted = grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                pendingPermissionResult?.success(granted)
                pendingPermissionResult = null
                true
            }
        }

    // MARK: - Adapter state

    private fun requestEnable(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            result.success(false)
            return
        }
        if (adapter.isEnabled) {
            result.success(true)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.success(false)
            return
        }

        if (pendingEnableResult != null) {
            result.error("BUSY", "An enable request is already in flight", null)
            return
        }

        pendingEnableResult = result
        currentActivity.startActivityForResult(
            Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
            REQUEST_ENABLE_BLUETOOTH
        )
    }

    private val activityResultListener =
        io.flutter.plugin.common.PluginRegistry.ActivityResultListener {
            requestCode, resultCode, _ ->
            if (requestCode != REQUEST_ENABLE_BLUETOOTH) {
                false
            } else {
                pendingEnableResult?.success(resultCode == Activity.RESULT_OK)
                pendingEnableResult = null
                true
            }
        }

    // MARK: - Devices

    private fun getPairedDevices(result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        val adapter = bluetoothAdapter
        if (adapter == null) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        // Return all bonded devices; filtering by name happens in the Dart layer.
        val devices = try {
            adapter.bondedDevices.orEmpty()
        } catch (e: SecurityException) {
            Log.w(TAG, "Missing permission for bondedDevices", e)
            emptySet<BluetoothDevice>()
        }

        result.success(
            devices.mapNotNull { device ->
                val name = try {
                    device.name
                } catch (e: SecurityException) {
                    null
                } ?: return@mapNotNull null
                mapOf("name" to name, "address" to device.address)
            }
        )
    }

    private fun startDiscovery() {
        val adapter = bluetoothAdapter ?: return
        val context = applicationContext ?: return
        if (!hasPermissions()) {
            Log.w(TAG, "startDiscovery: missing permissions")
            return
        }

        stopDiscovery()

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device: BluetoothDevice? =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                intent.getParcelableExtra(
                                    BluetoothDevice.EXTRA_DEVICE,
                                    BluetoothDevice::class.java
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                            }
                        val name = try {
                            device?.name
                        } catch (e: SecurityException) {
                            null
                        } ?: return
                        val address = device?.address ?: return
                        main.post {
                            methodChannel?.invokeMethod(
                                "onDeviceDiscovered",
                                mapOf("name" to name, "address" to address)
                            )
                        }
                    }

                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        main.post { methodChannel?.invokeMethod("onDiscoveryComplete", null) }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        context.registerReceiver(receiver, filter)
        discoveryReceiver = receiver

        try {
            adapter.startDiscovery()
        } catch (e: SecurityException) {
            Log.w(TAG, "startDiscovery denied", e)
        }
    }

    private fun stopDiscovery() {
        val context = applicationContext
        discoveryReceiver?.let { receiver ->
            try {
                context?.unregisterReceiver(receiver)
            } catch (e: IllegalArgumentException) {
                // Receiver was not registered; nothing to do.
            }
        }
        discoveryReceiver = null

        try {
            bluetoothAdapter?.cancelDiscovery()
        } catch (e: SecurityException) {
            Log.w(TAG, "cancelDiscovery denied", e)
        }
    }

    // MARK: - Connection

    private fun connect(address: String, result: MethodChannel.Result) {
        disconnect()

        val adapter = bluetoothAdapter
        if (adapter == null || !hasPermissions()) {
            result.success(false)
            return
        }

        emitState("connecting")

        // Discovery slows down or breaks an in-progress RFCOMM connect.
        try {
            adapter.cancelDiscovery()
        } catch (e: SecurityException) {
            Log.w(TAG, "cancelDiscovery denied", e)
        }

        // Socket connect blocks, so it must not run on the platform thread. The
        // result is completed exactly once, from the main thread.
        val replied = java.util.concurrent.atomic.AtomicBoolean(false)
        fun reply(success: Boolean) {
            if (replied.compareAndSet(false, true)) {
                main.post { result.success(success) }
            }
        }

        val worker = Thread({
            var pending: BluetoothSocket? = null
            try {
                val device = adapter.getRemoteDevice(address)
                pending = device.createRfcommSocketToServiceRecord(SPP_UUID)
                pending.connect()

                socket = pending
                outputStream = pending.outputStream

                startReadLoop(pending.inputStream)
                emitState("connected")
                reply(true)
            } catch (e: Exception) {
                Log.w(TAG, "connect to $address failed", e)
                try {
                    pending?.close()
                } catch (ignored: IOException) {
                }
                socket = null
                outputStream = null
                emitState("disconnected")
                reply(false)
            }
        }, "distox-connect")
        worker.start()

        // Fail fast; DistoXService retries via its own reconnect logic.
        main.postDelayed({
            if (!replied.get()) {
                Log.w(TAG, "connect to $address timed out")
                disconnect()
                reply(false)
            }
        }, CONNECT_TIMEOUT_MS)
    }

    private fun startReadLoop(input: InputStream) {
        val thread = Thread({
            val buffer = ByteArray(1024)
            try {
                while (!Thread.currentThread().isInterrupted) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (count == 0) continue
                    val chunk = buffer.copyOf(count)
                    main.post { dataSink?.success(chunk) }
                }
            } catch (e: IOException) {
                // Expected when the socket is closed from disconnect().
                Log.d(TAG, "read loop ended: ${e.message}")
            }
            main.post {
                if (socket != null) {
                    // Remote closed the link rather than us tearing it down.
                    closeSocket()
                    emitState("disconnected")
                }
            }
        }, "distox-read")
        thread.isDaemon = true
        readThread = thread
        thread.start()
    }

    private fun disconnect() {
        val wasConnected = socket != null
        readThread?.interrupt()
        readThread = null
        closeSocket()
        if (wasConnected) {
            emitState("disconnected")
        }
    }

    private fun closeSocket() {
        try {
            outputStream?.flush()
        } catch (ignored: IOException) {
        }
        try {
            socket?.close()
        } catch (ignored: IOException) {
        }
        outputStream = null
        socket = null
    }

    private fun send(data: ByteArray): Boolean {
        val stream = outputStream
        if (stream == null) {
            Log.w(TAG, "send failed - not connected")
            return false
        }
        return try {
            stream.write(data)
            stream.flush()
            true
        } catch (e: IOException) {
            Log.w(TAG, "send failed", e)
            false
        }
    }

    private fun emitState(state: String) {
        main.post { stateSink?.success(state) }
    }
}
