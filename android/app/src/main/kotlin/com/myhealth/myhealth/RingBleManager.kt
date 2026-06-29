package com.myhealth.myhealth

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.jstyle.blesdkx3.Util.BleSDK
import com.jstyle.blesdkx3.callback.DataListener2301
import io.flutter.plugin.common.EventChannel
import java.util.UUID

/**
 * BLE-менеджер кольца JCRing X3: скан, подключение, подписка на нотификации,
 * отправка команд и парсинг ответов через Jstyle SDK (com.jstyle.blesdkx3).
 * События уходят во Flutter через [EventChannel].
 */
@SuppressLint("MissingPermission")
class RingBleManager(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        private val SERVICE: UUID = UUID.fromString("0000fff0-0000-1000-8000-00805f9b34fb")
        private val WRITE: UUID = UUID.fromString("0000fff6-0000-1000-8000-00805f9b34fb")
        private val NOTIFY: UUID = UUID.fromString("0000fff7-0000-1000-8000-00805f9b34fb")
        private val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private val found = LinkedHashMap<String, ScanResult>()

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun emit(event: Map<String, Any?>) = main.post { sink?.success(event) }
    private fun emitState(state: String) = emit(mapOf("type" to "state", "state" to state))

    // --- Скан ---
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.device.name ?: result.scanRecord?.deviceName ?: return
            found[result.device.address] = result
            emit(
                mapOf(
                    "type" to "scan",
                    "devices" to found.values.map {
                        mapOf(
                            "id" to it.device.address,
                            "name" to (it.device.name ?: "Кольцо"),
                            "rssi" to it.rssi
                        )
                    }
                )
            )
        }
    }

    fun startScan() {
        val scanner = adapter?.bluetoothLeScanner ?: run {
            emitState("failed"); return
        }
        found.clear()
        emitState("scanning")
        scanner.startScan(scanCallback)
        // Авто-остановка скана через 12 секунд.
        main.postDelayed({ stopScan() }, 12_000)
    }

    fun stopScan() {
        adapter?.bluetoothLeScanner?.stopScan(scanCallback)
    }

    // --- Подключение ---
    fun connect(id: String) {
        stopScan()
        val device: BluetoothDevice = adapter?.getRemoteDevice(id) ?: run {
            emitState("failed"); return
        }
        emitState("connecting")
        gatt = device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    fun disconnect() {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        writeChar = null
        emitState("disconnected")
    }

    /** Запустить живое измерение (HR/температура/шаги). */
    fun measure() {
        write(BleSDK.RealTimeStep(true, true))
        write(BleSDK.GetDeviceBatteryLevel())
    }

    private fun write(bytes: ByteArray?) {
        val c = writeChar ?: return
        val g = gatt ?: return
        bytes ?: return
        c.value = bytes
        c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        g.writeCharacteristic(c)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                emitState("disconnected")
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            val service = g.getService(SERVICE) ?: run { emitState("failed"); return }
            writeChar = service.getCharacteristic(WRITE)
            val notify = service.getCharacteristic(NOTIFY) ?: run { emitState("failed"); return }
            g.setCharacteristicNotification(notify, true)
            notify.getDescriptor(CCCD)?.let {
                it.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                g.writeDescriptor(it)
            }
            emitState("connected")
            // Запускаем поток живых данных.
            main.postDelayed({ measure() }, 600)
        }

        @Deprecated("Compat for API < 33")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (c.uuid != NOTIFY) return
            BleSDK.DataParsingWithData(c.value, dataListener)
        }
    }

    // --- Парсинг ответов SDK -> события Flutter ---
    private val dataListener = object : DataListener2301 {
        override fun dataCallback(maps: MutableMap<String, Any>?) {
            maps ?: return
            val out = HashMap<String, Any?>()
            out["type"] = "data"
            (maps["HeartRate"] ?: maps["heartValue"])?.let { out["heartRate"] = toInt(it) }
            (maps["Sp02"])?.let { out["spo2"] = toInt(it) }
            (maps["Final_temperature_value"])?.let { out["temperature"] = toDouble(it) }
            (maps["hrvValue"])?.let { out["hrv"] = toInt(it) }
            (maps["Power"] ?: maps["battery"] ?: maps["Battery"])?.let { out["battery"] = toInt(it) }
            (maps["Step"] ?: maps["StepValue"] ?: maps["steps"])?.let { out["steps"] = toInt(it) }
            if (out.size > 1) emit(out)
        }

        override fun dataCallback(value: ByteArray?) {}
    }

    private fun toInt(v: Any?): Int? = (v as? Number)?.toInt() ?: (v as? String)?.toDoubleOrNull()?.toInt()
    private fun toDouble(v: Any?): Double? = (v as? Number)?.toDouble() ?: (v as? String)?.toDoubleOrNull()
}
