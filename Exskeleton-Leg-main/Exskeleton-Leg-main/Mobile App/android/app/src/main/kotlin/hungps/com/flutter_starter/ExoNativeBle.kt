package com.flutter.nextai

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel.EventSink
import java.util.UUID

/** Native Android BLE transport for the ExoLeg control point.
 *
 * This intentionally does not call createBond(). A bond is unnecessary for
 * the Pi GATT permissions. If Android reports an in-progress bond, operations
 * wait for its terminal state before service discovery instead of failing the
 * operation from the Flutter plugin layer.
 */
class ExoNativeBle(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val CHANNEL = "exo_leg/native_ble"
        private const val STATUS_CHANNEL = "exo_leg/native_ble_status"
        private const val SERVICE = "6e400101-b5a3-f393-e0a9-e50e24dcca9e"
        private const val CONTROL = "6e400102-b5a3-f393-e0a9-e50e24dcca9e"
        private const val STATUS = "6e400103-b5a3-f393-e0a9-e50e24dcca9e"
        private const val CCCD = "00002902-0000-1000-8000-00805f9b34fb"
        private const val TIMEOUT_MS = 20_000L
        private const val OPERATION_TIMEOUT_MS = 8_000L
        // Android 14+ can negotiate the ATT MTU automatically immediately
        // after connecting. Starting service discovery at the same time can
        // leave BlueZ without an onServicesDiscovered callback.
        private const val DISCOVERY_FALLBACK_MS = 1_000L

        private val serviceUuid = UUID.fromString(SERVICE)
        private val controlUuid = UUID.fromString(CONTROL)
        private val statusUuid = UUID.fromString(STATUS)
        private val cccdUuid = UUID.fromString(CCCD)
    }

    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, CHANNEL)
    private val statusChannel = EventChannel(messenger, STATUS_CHANNEL)
    private var statusSink: EventSink? = null
    private var gatt: BluetoothGatt? = null
    private var control: BluetoothGattCharacteristic? = null
    private var status: BluetoothGattCharacteristic? = null
    private var pendingConnect: MethodChannel.Result? = null
    private var pendingWrite: MethodChannel.Result? = null
    private var pendingSubscribe: MethodChannel.Result? = null
    private var bondReceiver: BroadcastReceiver? = null
    private var timeout: Runnable? = null
    private var operationTimeout: Runnable? = null
    private var discoveryStarted = false

    init {
        channel.setMethodCallHandler(this)
        statusChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> connect(call.argument<String>("deviceId"), result)
            "write" -> write(call.argument<Any?>("value"), result)
            "subscribe" -> subscribe(result)
            "disconnect" -> {
                closeGatt()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun connect(deviceId: String?, result: MethodChannel.Result) {
        if (deviceId == null) {
            result.error("invalid_device", "Missing Bluetooth device id", null)
            return
        }
        if (!hasConnectPermission()) {
            result.error("permission", "BLUETOOTH_CONNECT is not granted", null)
            return
        }
        closeGatt()
        pendingConnect = result
        val device = activity.getSystemService(Context.BLUETOOTH_SERVICE)
            .let { (it as android.bluetooth.BluetoothManager).adapter.getRemoteDevice(deviceId) }
        armTimeout("connect")
        if (device.bondState == BluetoothDevice.BOND_BONDING) {
            waitForBondBeforeConnect(device)
        } else {
            openGatt(device)
        }
    }

    private fun openGatt(device: BluetoothDevice) {
        discoveryStarted = false
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(activity, false, callback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(activity, false, callback)
        }
    }

    private fun write(raw: Any?, result: MethodChannel.Result) {
        val bytes = when (raw) {
            is ByteArray -> raw
            is List<*> -> raw.mapNotNull { (it as? Number)?.toByte() }.toByteArray()
            else -> null
        }
        val characteristic = control
        if (bytes == null || characteristic == null || gatt == null) {
            result.error("not_connected", "ExoLeg GATT is not ready", null)
            return
        }
        if (pendingWrite != null) {
            result.error("busy", "A BLE write is already in progress", null)
            return
        }
        pendingWrite = result
        armOperationTimeout("write") {
            val pending = pendingWrite ?: return@armOperationTimeout
            pendingWrite = null
            pending.error("write_timeout", "BLE write timed out", null)
            failConnection("BLE write timed out")
        }
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        characteristic.value = bytes
        if (!gatt!!.writeCharacteristic(characteristic)) {
            finishWrite(false, "BluetoothGatt.writeCharacteristic returned false")
        }
    }

    private fun subscribe(result: MethodChannel.Result) {
        val characteristic = status
        val currentGatt = gatt
        if (characteristic == null || currentGatt == null) {
            result.error("not_connected", "Status characteristic is not ready", null)
            return
        }
        if (pendingSubscribe != null || pendingWrite != null) {
            result.error("busy", "A BLE GATT operation is already in progress", null)
            return
        }
        if (!currentGatt.setCharacteristicNotification(characteristic, true)) {
            result.error("notify", "Could not enable local notifications", null)
            return
        }
        val descriptor = characteristic.getDescriptor(cccdUuid)
        if (descriptor == null) {
            result.success(null)
            return
        }
        pendingSubscribe = result
        armOperationTimeout("subscribe") {
            val pending = pendingSubscribe ?: return@armOperationTimeout
            pendingSubscribe = null
            pending.error("notify_timeout", "BLE notification setup timed out", null)
            failConnection("BLE notification setup timed out")
        }
        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        if (!currentGatt.writeDescriptor(descriptor)) {
            cancelOperationTimeout()
            pendingSubscribe = null
            result.error("notify", "Could not write notification descriptor", null)
        }
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, statusCode: Int, newState: Int) {
            if (gatt !== this@ExoNativeBle.gatt) {
                gatt.close()
                return
            }
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                if (gatt.device.bondState == BluetoothDevice.BOND_BONDING) {
                    waitForBondThenDiscover(gatt)
                } else {
                    scheduleDiscovery(gatt)
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                failConnection("GATT disconnected (status=$statusCode)")
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, statusCode: Int) {
            if (gatt !== this@ExoNativeBle.gatt) return
            discover(gatt)
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, statusCode: Int) {
            if (gatt !== this@ExoNativeBle.gatt) return
            if (statusCode != BluetoothGatt.GATT_SUCCESS) {
                failConnect("Service discovery failed (status=$statusCode)")
                return
            }
            control = gatt.getService(serviceUuid)?.getCharacteristic(controlUuid)
            status = gatt.getService(serviceUuid)?.getCharacteristic(statusUuid)
            if (control == null || status == null) {
                failConnect("ExoLeg service or characteristic not found")
                return
            }
            cancelTimeout()
            pendingConnect?.success(null)
            pendingConnect = null
            emitTransportStatus("services_ready", "")
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            statusCode: Int,
        ) {
            if (gatt !== this@ExoNativeBle.gatt) return
            if (characteristic.uuid == controlUuid) {
                finishWrite(statusCode == BluetoothGatt.GATT_SUCCESS, "GATT status=$statusCode")
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            statusCode: Int,
        ) {
            if (gatt !== this@ExoNativeBle.gatt) return
            if (descriptor.uuid == cccdUuid) {
                cancelOperationTimeout()
                val result = pendingSubscribe ?: return
                pendingSubscribe = null
                if (statusCode == BluetoothGatt.GATT_SUCCESS) {
                    result.success(null)
                } else {
                    result.error("notify", "GATT descriptor status=$statusCode", null)
                }
            }
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
        ) {
            if (gatt === this@ExoNativeBle.gatt && characteristic.uuid == statusUuid) emitStatus(characteristic.value)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            if (gatt === this@ExoNativeBle.gatt && characteristic.uuid == statusUuid) emitStatus(value)
        }
    }

    private fun discover(currentGatt: BluetoothGatt) {
        if (currentGatt !== gatt || discoveryStarted) return
        discoveryStarted = true
        if (!currentGatt.discoverServices()) failConnect("BluetoothGatt.discoverServices returned false")
    }

    private fun scheduleDiscovery(currentGatt: BluetoothGatt) {
        main.postDelayed({ discover(currentGatt) }, DISCOVERY_FALLBACK_MS)
    }

    private fun waitForBondThenDiscover(currentGatt: BluetoothGatt) {
        bondReceiver?.let { activity.unregisterReceiver(it) }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                if (device?.address != currentGatt.device.address) return
                val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                if (state == BluetoothDevice.BOND_NONE || state == BluetoothDevice.BOND_BONDED) {
                    activity.unregisterReceiver(this)
                    bondReceiver = null
                    scheduleDiscovery(currentGatt)
                }
            }
        }
        bondReceiver = receiver
        activity.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
    }

    private fun waitForBondBeforeConnect(device: BluetoothDevice) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val changed = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                if (changed?.address != device.address) return
                val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)
                if (state == BluetoothDevice.BOND_NONE || state == BluetoothDevice.BOND_BONDED) {
                    activity.unregisterReceiver(this)
                    bondReceiver = null
                    openGatt(device)
                }
            }
        }
        bondReceiver = receiver
        activity.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
        // Do not call removeBond here. Android can report BOND_BONDING while
        // the GATT link is already becoming usable; removing it races with
        // service discovery and commonly produces status=257.
    }

    private fun emitStatus(value: ByteArray) {
        main.post { statusSink?.success(value.toList()) }
    }

    private fun finishWrite(ok: Boolean, message: String) {
        val result = pendingWrite ?: return
        cancelOperationTimeout()
        pendingWrite = null
        if (ok) result.success(null) else result.error("write", message, null)
    }

    private fun failConnect(message: String) {
        cancelTimeout()
        pendingConnect?.error("connect", message, null)
        pendingConnect = null
        failConnection(message)
    }

    private fun failConnection(message: String) {
        cancelTimeout()
        cancelOperationTimeout()
        pendingConnect?.error("connect", message, null)
        pendingConnect = null
        pendingWrite?.error("write", message, null)
        pendingWrite = null
        pendingSubscribe?.error("notify", message, null)
        pendingSubscribe = null
        val current = gatt
        gatt = null
        control = null
        status = null
        discoveryStarted = false
        current?.close()
        emitTransportStatus("disconnected", message)
    }

    private fun armTimeout(operation: String) {
        cancelTimeout()
        val task = Runnable {
            if (operation == "connect") failConnect("BLE $operation timed out")
        }
        timeout = task
        main.postDelayed(task, TIMEOUT_MS)
    }

    private fun cancelTimeout() {
        timeout?.let(main::removeCallbacks)
        timeout = null
    }

    private fun armOperationTimeout(operation: String, action: () -> Unit) {
        cancelOperationTimeout()
        val task = Runnable(action)
        operationTimeout = task
        main.postDelayed(task, OPERATION_TIMEOUT_MS)
    }

    private fun cancelOperationTimeout() {
        operationTimeout?.let(main::removeCallbacks)
        operationTimeout = null
    }

    private fun emitTransportStatus(state: String, reason: String) {
        val safeReason = reason.replace("\\", "\\\\").replace("\"", "\\\"")
        emitStatus("{\"v\":1,\"type\":\"transport_status\",\"state\":\"$state\",\"reason\":\"$safeReason\"}".toByteArray())
    }

    private fun closeGatt() {
        cancelTimeout()
        cancelOperationTimeout()
        pendingConnect?.error("cancelled", "Previous BLE connection was cancelled", null)
        pendingConnect = null
        pendingWrite?.error("cancelled", "BLE connection was closed", null)
        pendingWrite = null
        pendingSubscribe?.error("cancelled", "BLE connection was closed", null)
        pendingSubscribe = null
        bondReceiver?.let {
            runCatching { activity.unregisterReceiver(it) }
            bondReceiver = null
        }
        val current = gatt
        gatt = null
        control = null
        status = null
        discoveryStarted = false
        current?.disconnect()
        current?.close()
    }

    private fun hasConnectPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ActivityCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    override fun onListen(arguments: Any?, events: EventSink?) {
        statusSink = events
    }

    override fun onCancel(arguments: Any?) {
        statusSink = null
    }
}
