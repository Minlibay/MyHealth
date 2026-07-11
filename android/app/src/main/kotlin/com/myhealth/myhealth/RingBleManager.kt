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
import com.jstyle.blesdkx3.model.AutoMode
import com.jstyle.blesdkx3.model.MyAutomaticHRMonitoring
import com.jstyle.blesdkx3.model.MyDeviceTime
import com.jstyle.blesdkx3.model.MyPersonalInfo
import io.flutter.plugin.common.EventChannel
import java.util.ArrayDeque
import java.util.UUID

/**
 * BLE-менеджер кольца JCRing X3: скан, подключение, живые данные и
 * выкачивание истории (сон по фазам, пульс, HRV, SpO2, температура,
 * активность) через Jstyle SDK (com.jstyle.blesdkx3).
 *
 * Ответы SDK приходят конвертом {dataType, dataEnd, dicData}; история —
 * пачками по ~50 записей: mode=0 читает первую, mode=2 — продолжение,
 * пока dataEnd не станет true.
 */
@SuppressLint("MissingPermission")
class RingBleManager(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        private val SERVICE: UUID = UUID.fromString("0000fff0-0000-1000-8000-00805f9b34fb")
        private val WRITE: UUID = UUID.fromString("0000fff6-0000-1000-8000-00805f9b34fb")
        private val NOTIFY: UUID = UUID.fromString("0000fff7-0000-1000-8000-00805f9b34fb")
        private val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        private const val MODE_READ_START: Byte = 0
        private const val MODE_READ_CONTINUE: Byte = 2

        /** Таймаут одного шага истории: нет ответа — переходим к следующему типу. */
        private const val HISTORY_STEP_TIMEOUT_MS = 15_000L
    }

    /** Тип истории: имя для Flutter + dataType конверта SDK + команда чтения. */
    private data class HistoryKind(
        val name: String,
        val dataType: String,
        val command: (Byte) -> ByteArray,
    )

    private val historyKinds = listOf(
        HistoryKind("activity", "24") { m -> BleSDK.GetTotalActivityDataWithMode(m, "") },
        HistoryKind("sleep", "26") { m -> BleSDK.GetDetailSleepDataWithMode(m, "") },
        HistoryKind("dynamicHr", "27") { m -> BleSDK.GetDynamicHRWithMode(m, "") },
        HistoryKind("staticHr", "28") { m -> BleSDK.GetStaticHRWithMode(m, "") },
        HistoryKind("hrv", "42") { m -> BleSDK.GetHRVDataWithMode(m, "") },
        HistoryKind("spo2", "68") { m -> BleSDK.Oxygen_data(m, "") },
        HistoryKind("temperature", "59") { m -> BleSDK.GetTemperature_historyData(m, "") },
    )

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private val found = LinkedHashMap<String, ScanResult>()

    // Очередь записи: следующая команда уходит только после подтверждения
    // предыдущей (onCharacteristicWrite), иначе стек BLE теряет пакеты.
    private val writeQueue = ArrayDeque<ByteArray>()
    private var writing = false

    // Состояние синхронизации истории.
    private var historyQueue: MutableList<HistoryKind> = mutableListOf()
    private var currentKind: HistoryKind? = null
    private var historyTimeout: Runnable? = null

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
    /**
     * Показываем только кольца Jstyle: устройство либо рекламирует сервис
     * fff0, либо его имя похоже на кольцо. Иначе в списке оказываются все
     * BLE-устройства вокруг (наушники, телевизоры и т.д.).
     */
    private fun isRingDevice(result: ScanResult): Boolean {
        val advertisesService = result.scanRecord?.serviceUuids
            ?.any { it.uuid == SERVICE } == true
        if (advertisesService) return true
        val name = (result.device.name ?: result.scanRecord?.deviceName ?: "").lowercase()
        return name.contains("ring") || name.startsWith("jc") || name.startsWith("j-style") ||
            name.startsWith("jstyle")
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.device.name ?: result.scanRecord?.deviceName ?: return
            if (!isRingDevice(result)) return
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
        val a = adapter
        if (a == null || !a.isEnabled) {
            emitState("failed"); return
        }
        val scanner = a.bluetoothLeScanner ?: run {
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
    /**
     * [auto] = true — фоновое переподключение (после перезапуска приложения):
     * стек BLE сам подключится, как только кольцо окажется в зоне действия.
     * Ошибки автоподключения не показываем — кольцо может быть просто
     * вне зоны или Bluetooth ещё включается.
     */
    fun connect(id: String, auto: Boolean = false) {
        stopScan()
        val device: BluetoothDevice = adapter?.takeIf { it.isEnabled }?.getRemoteDevice(id)
            ?: run {
                if (!auto) emitState("failed")
                return
            }
        if (!auto) emitState("connecting")
        gatt = device.connectGatt(context, auto, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    fun disconnect() {
        cancelHistorySync()
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        writeChar = null
        writeQueue.clear()
        writing = false
        emitState("disconnected")
    }

    /** Запустить живое измерение (HR/температура/шаги). */
    fun measure() {
        enqueueWrite(BleSDK.SetDeviceTime(MyDeviceTime())) // заодно синхронизируем часы
        enqueueWrite(BleSDK.RealTimeStep(true, true))
        enqueueWrite(BleSDK.GetDeviceBatteryLevel())
    }

    /** Записать профиль пользователя в кольцо (точность калорий/дистанции). */
    fun setProfile(gender: Int, age: Int, height: Int, weight: Int) {
        val info = MyPersonalInfo()
        info.sex = gender
        info.age = age
        info.height = height
        info.weight = weight
        info.stepLength = 70
        enqueueWrite(BleSDK.SetPersonalInfo(info))
    }

    /**
     * Включить автозамеры на кольце: интервальный режим на весь день,
     * все дни недели. Без этого истории не будет.
     */
    fun enableAutoMonitoring(intervalMinutes: Int) {
        for (mode in listOf(AutoMode.AutoHeartRate, AutoMode.AutoSpo2, AutoMode.AutoTemp, AutoMode.AutoHrv)) {
            val cfg = MyAutomaticHRMonitoring()
            cfg.open = 2 // 2 = интервальные замеры внутри окна
            cfg.startHour = 0
            cfg.startMinute = 0
            cfg.endHour = 23
            cfg.endMinute = 59
            cfg.week = 0x7F // все дни недели
            cfg.time = intervalMinutes
            enqueueWrite(BleSDK.SetAutomaticHRMonitoring(cfg, mode))
        }
    }

    /** Выкачать всю накопленную историю с кольца (по типам, с пагинацией). */
    fun syncHistory() {
        if (gatt == null || writeChar == null) {
            emit(mapOf("type" to "historyDone", "ok" to false, "error" to "not_connected"))
            return
        }
        cancelHistorySync()
        historyQueue = historyKinds.toMutableList()
        nextHistoryKind()
    }

    private fun cancelHistorySync() {
        historyTimeout?.let { main.removeCallbacks(it) }
        historyTimeout = null
        historyQueue.clear()
        currentKind = null
    }

    private fun nextHistoryKind() {
        historyTimeout?.let { main.removeCallbacks(it) }
        if (historyQueue.isEmpty()) {
            currentKind = null
            emit(mapOf("type" to "historyDone", "ok" to true))
            return
        }
        val kind = historyQueue.removeAt(0)
        currentKind = kind
        enqueueWrite(kind.command(MODE_READ_START))
        armHistoryTimeout()
    }

    private fun armHistoryTimeout() {
        historyTimeout?.let { main.removeCallbacks(it) }
        val timeout = Runnable {
            // Кольцо не ответило по текущему типу — идём дальше.
            if (currentKind != null) nextHistoryKind()
        }
        historyTimeout = timeout
        main.postDelayed(timeout, HISTORY_STEP_TIMEOUT_MS)
    }

    // --- Очередь записи в характеристику ---
    private fun enqueueWrite(bytes: ByteArray?) {
        bytes ?: return
        writeQueue.add(bytes)
        drainWriteQueue()
    }

    private fun drainWriteQueue() {
        if (writing) return
        val c = writeChar ?: return
        val g = gatt ?: return
        val bytes = writeQueue.poll() ?: return
        writing = true
        c.value = bytes
        c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        g.writeCharacteristic(c)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                // Больший MTU, чтобы пачки истории не резались на фрагменты.
                g.requestMtu(512)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                cancelHistorySync()
                emitState("disconnected")
            }
        }

        override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
            g.discoverServices()
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

        override fun onCharacteristicWrite(
            g: BluetoothGatt,
            c: BluetoothGattCharacteristic,
            status: Int
        ) {
            writing = false
            drainWriteQueue()
        }

        @Deprecated("Compat for API < 33")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (c.uuid != NOTIFY) return
            BleSDK.DataParsingWithData(c.value, dataListener)
        }
    }

    // --- Парсинг ответов SDK -> события Flutter ---
    // SDK всегда возвращает конверт {dataType: String, dataEnd: Boolean,
    // dicData: Map | List<Map>}; диспетчеризация по dataType.
    private val dataListener = object : DataListener2301 {
        override fun dataCallback(maps: MutableMap<String, Any>?) {
            maps ?: return
            val dataType = maps["dataType"]?.toString() ?: return
            val dataEnd = maps["dataEnd"] as? Boolean ?: true
            val dicData = maps["dicData"]

            // История?
            val kind = currentKind
            if (kind != null && dataType == kind.dataType) {
                val records = (dicData as? List<*>)?.mapNotNull { rec ->
                    (rec as? Map<*, *>)?.entries?.associate { (k, v) ->
                        k.toString() to v?.toString()
                    }
                } ?: emptyList()
                if (records.isNotEmpty()) {
                    emit(mapOf("type" to "history", "kind" to kind.name, "records" to records))
                }
                if (dataEnd) {
                    nextHistoryKind()
                } else {
                    enqueueWrite(kind.command(MODE_READ_CONTINUE))
                    armHistoryTimeout()
                }
                return
            }

            // Живые данные и батарея.
            val record = dicData as? Map<*, *> ?: return
            fun rec(key: String): Any? = record[key]
            val out = HashMap<String, Any?>()
            out["type"] = "data"
            when (dataType) {
                "23" -> { // RealTimeStep
                    rec("HeartRate")?.let { out["heartRate"] = toInt(it) }
                    rec("Blood_oxygen")?.let { out["spo2"] = toInt(it) }
                    rec("TempData")?.let { out["temperature"] = toDouble(it) }
                    rec("step")?.let { out["steps"] = toInt(it) }
                }
                "9" -> { // батарея
                    rec("batteryLevel")?.let { out["battery"] = toInt(it) }
                }
                else -> return
            }
            if (out.size > 1) emit(out)
        }

        override fun dataCallback(value: ByteArray?) {}
    }

    private fun toInt(v: Any?): Int? = (v as? Number)?.toInt() ?: (v as? String)?.toDoubleOrNull()?.toInt()
    private fun toDouble(v: Any?): Double? = (v as? Number)?.toDouble() ?: (v as? String)?.toDoubleOrNull()
}
