package ch.tierry.mobiletopo

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.os.Handler
import android.util.Log
import java.util.UUID

/**
 * Bluetooth Low Energy link to a DistoX BLE.
 *
 * The DistoX BLE (docs/distox6/Disto xble comm protocol.pdf) has one service
 * with a characteristic to write commands to and one notifying the packets it
 * sends. This only moves bytes; the Dart side (lib/services/distox_framing.dart)
 * knows what they mean.
 *
 * GATT callbacks arrive on a binder thread; they are posted to [main], where
 * all state lives and every callback of this class is called.
 */
@SuppressLint("MissingPermission") // BluetoothPlugin checks them before connecting
class BleConnection(
    private val context: Context,
    private val main: Handler,
    private val onData: (ByteArray) -> Unit,
    private val onDisconnected: () -> Unit,
) {
    companion object {
        private const val TAG = "BleConnection"

        val SERVICE_UUID: UUID = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        val WRITE_UUID: UUID = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
        val NOTIFY_UUID: UUID = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")

        /** Client Characteristic Configuration, which turns notifications on. */
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private var gatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var pendingConnect: ((Boolean) -> Unit)? = null
    private val timeout = Runnable {
        Log.w(TAG, "connect timed out")
        close()
    }

    /** Writes in order; Android runs one GATT operation at a time. */
    private val writes = ArrayDeque<Pair<ByteArray, (Boolean) -> Unit>>()
    private var writing = false

    val isConnected: Boolean
        get() = gatt != null && pendingConnect == null

    /** Connect to [device] and subscribe to its packets. */
    fun connect(device: BluetoothDevice, timeoutMs: Long, done: (Boolean) -> Unit) {
        close()
        pendingConnect = done
        main.postDelayed(timeout, timeoutMs)
        gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        if (gatt == null) finishConnect(false)
    }

    /** End the link, failing a connect or writes still pending. */
    fun close() {
        val current = gatt
        gatt = null
        writeCharacteristic = null
        failWrites()
        finishConnect(false)
        current?.disconnect()
        current?.close()
    }

    /** Write [data] to the device; [done] is called once it went out. */
    fun send(data: ByteArray, done: (Boolean) -> Unit) {
        if (!isConnected || writeCharacteristic == null) {
            Log.w(TAG, "send failed - not connected")
            done(false)
            return
        }
        writes.addLast(data to done)
        writeNext()
    }

    private fun writeNext() {
        if (writing) return
        val (data, done) = writes.firstOrNull() ?: return
        val current = gatt
        val characteristic = writeCharacteristic
        if (current == null || characteristic == null) {
            failWrites()
            return
        }
        val type =
            if (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) {
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            } else {
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            }
        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            current.writeCharacteristic(characteristic, data, type) == BluetoothGatt.GATT_SUCCESS
        } else {
            @Suppress("DEPRECATION")
            characteristic.writeType = type
            @Suppress("DEPRECATION")
            characteristic.value = data
            @Suppress("DEPRECATION")
            current.writeCharacteristic(characteristic)
        }
        if (started) {
            writing = true
        } else {
            Log.w(TAG, "write could not start")
            writes.removeFirst()
            done(false)
            writeNext()
        }
    }

    private fun failWrites() {
        val failed = writes.toList()
        writes.clear()
        writing = false
        failed.forEach { (_, done) -> done(false) }
    }

    private fun finishConnect(success: Boolean) {
        main.removeCallbacks(timeout)
        val done = pendingConnect ?: return
        pendingConnect = null
        if (!success) {
            val current = gatt
            gatt = null
            writeCharacteristic = null
            current?.disconnect()
            current?.close()
        }
        done(success)
    }

    private fun enableNotifications(current: BluetoothGatt) {
        val service = current.getService(SERVICE_UUID)
        val write = service?.getCharacteristic(WRITE_UUID)
        val notify = service?.getCharacteristic(NOTIFY_UUID)
        val cccd = notify?.getDescriptor(CCCD_UUID)
        if (write == null || notify == null || cccd == null) {
            Log.w(TAG, "DistoX service not found")
            finishConnect(false)
            return
        }
        writeCharacteristic = write
        current.setCharacteristicNotification(notify, true)
        val value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            current.writeDescriptor(cccd, value) == BluetoothGatt.GATT_SUCCESS
        } else {
            @Suppress("DEPRECATION")
            cccd.value = value
            @Suppress("DEPRECATION")
            current.writeDescriptor(cccd)
        }
        if (!started) finishConnect(false)
    }

    private fun received(from: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        if (characteristic.uuid != NOTIFY_UUID) return
        val chunk = value.copyOf()
        main.post { if (from == gatt) onData(chunk) }
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(from: BluetoothGatt, status: Int, newState: Int) {
            main.post {
                if (from != gatt) return@post
                if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                    if (!from.discoverServices()) finishConnect(false)
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED ||
                    status != BluetoothGatt.GATT_SUCCESS
                ) {
                    Log.d(TAG, "disconnected (status $status)")
                    val wasConnected = isConnected
                    gatt = null
                    writeCharacteristic = null
                    failWrites()
                    from.close()
                    finishConnect(false)
                    if (wasConnected) onDisconnected()
                }
            }
        }

        override fun onServicesDiscovered(from: BluetoothGatt, status: Int) {
            main.post {
                if (from != gatt) return@post
                if (status == BluetoothGatt.GATT_SUCCESS) enableNotifications(from) else finishConnect(false)
            }
        }

        override fun onDescriptorWrite(from: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            main.post {
                // Connected once the device's packets reach us
                if (from == gatt && descriptor.uuid == CCCD_UUID) {
                    finishConnect(status == BluetoothGatt.GATT_SUCCESS)
                }
            }
        }

        override fun onCharacteristicWrite(
            from: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            main.post {
                if (from != gatt || !writing) return@post
                writing = false
                val (_, done) = writes.removeFirstOrNull() ?: return@post
                if (status != BluetoothGatt.GATT_SUCCESS) Log.w(TAG, "write failed (status $status)")
                done(status == BluetoothGatt.GATT_SUCCESS)
                writeNext()
            }
        }

        override fun onCharacteristicChanged(
            from: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) = received(from, characteristic, value)

        @Deprecated("Called instead of the one with the value before Android 13")
        override fun onCharacteristicChanged(from: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            // Android 13 and later may call this too, besides the one above
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                @Suppress("DEPRECATION")
                received(from, characteristic, characteristic.value ?: return)
            }
        }
    }
}
