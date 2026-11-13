package app.cardloader.link

import android.content.Context
import android.os.Handler
import android.os.Looper
import app.cardloader.codec.Contract
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * The Connect IQ Mobile SDK in wireless mode: messages go through the Garmin Connect app to the
 * watch. Nothing here reads a card; it carries the message it is given.
 */
class ConnectIqWatchLink(context: Context) : WatchLink {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val ciq: ConnectIQ = ConnectIQ.getInstance(appContext, ConnectIQ.IQConnectType.WIRELESS)
    private val widget = IQApp(Contract.WATCH_APP_ID)

    private val _state = MutableStateFlow<WatchState>(WatchState.Starting)
    override val state: StateFlow<WatchState> get() = _state

    private val devices = LinkedHashMap<Long, IQDevice>()
    private val states = HashMap<Long, DeviceState>()
    private val watchedDevices = HashSet<Long>()
    private var selectedId: Long? = null
    private var ready = false
    private var listening: IQDevice? = null

    override fun start() {
        try {
            ciq.initialize(appContext, false, object : ConnectIQ.ConnectIQListener {
                override fun onSdkReady() {
                    main.post {
                        ready = true
                        refresh()
                    }
                }

                override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus) {
                    main.post {
                        ready = false
                        _state.value = when (status) {
                            ConnectIQ.IQSdkErrorStatus.GCM_NOT_INSTALLED -> WatchState.GarminConnectMissing
                            ConnectIQ.IQSdkErrorStatus.GCM_UPGRADE_NEEDED -> WatchState.GarminConnectTooOld
                            else -> WatchState.ServiceError
                        }
                    }
                }

                override fun onSdkShutDown() {
                    main.post { ready = false }
                }
            })
        } catch (e: Exception) {
            _state.value = WatchState.ServiceError
        }
    }

    override fun refresh() {
        if (!ready) return
        try {
            val known = ciq.getKnownDevices() ?: emptyList()
            devices.clear()
            for (device in known) {
                val id = device.deviceIdentifier
                devices[id] = device
                states[id] = map(ciq.getDeviceStatus(device))
                if (watchedDevices.add(id)) {
                    ciq.registerForDeviceEvents(device) { changed, status ->
                        main.post {
                            states[changed.deviceIdentifier] = map(status)
                            publish()
                        }
                    }
                }
            }
            publish()
        } catch (e: Exception) {
            _state.value = WatchState.ServiceError
        }
    }

    private fun publish() {
        val list = devices.values.map { WatchDevice(it.deviceIdentifier, it.friendlyName ?: "Watch", states[it.deviceIdentifier] ?: DeviceState.UNKNOWN) }
        if (selectedId == null || list.none { it.id == selectedId }) {
            selectedId = (list.firstOrNull { it.state == DeviceState.CONNECTED } ?: list.firstOrNull())?.id
        }
        _state.value = WatchState.Ready(list, selectedId)
    }

    override fun select(deviceId: Long) {
        if (devices.containsKey(deviceId)) {
            selectedId = deviceId
            publish()
        }
    }

    override fun listen(deviceId: Long, onPayload: (List<Any?>) -> Unit) {
        val device = devices[deviceId] ?: return
        try {
            stopListening()
            ciq.registerForAppEvents(device, widget) { _, _, messages, status ->
                if (status == ConnectIQ.IQMessageStatus.SUCCESS) {
                    val copy: List<Any?> = messages?.toList() ?: emptyList()
                    main.post { onPayload(copy) }
                }
            }
            listening = device
        } catch (e: Exception) {
            // The answer cannot be heard; the screen will say that the widget stores the card when it is opened.
        }
    }

    override fun stopListening() {
        val device = listening ?: return
        listening = null
        try {
            ciq.unregisterForApplicationEvents(device, widget)
        } catch (e: Exception) {
            // Already gone.
        }
    }

    override fun send(deviceId: Long, message: Map<String, Any>, onDelivery: (Delivery) -> Unit): Boolean {
        val device = devices[deviceId]
        if (device == null) {
            main.post { onDelivery(Delivery.INVALID_DEVICE) }
            return false
        }
        return try {
            ciq.sendMessage(device, widget, message) { _, _, status ->
                main.post { onDelivery(map(status)) }
            }
            true
        } catch (e: Exception) {
            main.post { onDelivery(Delivery.LINK_ERROR) }
            false
        }
    }

    override fun openWidget(deviceId: Long, onResult: (OpenResult) -> Unit) {
        val device = devices[deviceId]
        if (device == null) {
            main.post { onResult(OpenResult.LINK_ERROR) }
            return
        }
        try {
            ciq.openApplication(device, widget) { _, _, status ->
                main.post {
                    onResult(
                        when (status) {
                            ConnectIQ.IQOpenApplicationStatus.PROMPT_SHOWN_ON_DEVICE -> OpenResult.PROMPT_SHOWN
                            ConnectIQ.IQOpenApplicationStatus.PROMPT_NOT_SHOWN_ON_DEVICE -> OpenResult.PROMPT_NOT_SHOWN
                            ConnectIQ.IQOpenApplicationStatus.APP_IS_NOT_INSTALLED -> OpenResult.NOT_INSTALLED
                            ConnectIQ.IQOpenApplicationStatus.APP_IS_ALREADY_RUNNING -> OpenResult.ALREADY_RUNNING
                            else -> OpenResult.UNKNOWN_FAILURE
                        },
                    )
                }
            }
        } catch (e: Exception) {
            main.post { onResult(OpenResult.LINK_ERROR) }
        }
    }

    override fun shutdown() {
        stopListening()
        try {
            ciq.unregisterAllForEvents()
        } catch (e: Exception) {
            // Not initialized.
        }
        try {
            ciq.shutdown(appContext)
        } catch (e: Exception) {
            // Not initialized.
        }
        ready = false
    }

    private fun map(status: com.garmin.android.connectiq.IQDevice.IQDeviceStatus?): DeviceState = when (status) {
        com.garmin.android.connectiq.IQDevice.IQDeviceStatus.CONNECTED -> DeviceState.CONNECTED
        com.garmin.android.connectiq.IQDevice.IQDeviceStatus.NOT_CONNECTED -> DeviceState.NOT_CONNECTED
        com.garmin.android.connectiq.IQDevice.IQDeviceStatus.NOT_PAIRED -> DeviceState.NOT_PAIRED
        else -> DeviceState.UNKNOWN
    }

    private fun map(status: ConnectIQ.IQMessageStatus?): Delivery = when (status) {
        ConnectIQ.IQMessageStatus.SUCCESS -> Delivery.SUCCESS
        ConnectIQ.IQMessageStatus.FAILURE_INVALID_FORMAT -> Delivery.INVALID_FORMAT
        ConnectIQ.IQMessageStatus.FAILURE_MESSAGE_TOO_LARGE -> Delivery.TOO_LARGE
        ConnectIQ.IQMessageStatus.FAILURE_UNSUPPORTED_TYPE -> Delivery.UNSUPPORTED_TYPE
        ConnectIQ.IQMessageStatus.FAILURE_DURING_TRANSFER -> Delivery.TRANSFER_FAILED
        ConnectIQ.IQMessageStatus.FAILURE_INVALID_DEVICE -> Delivery.INVALID_DEVICE
        ConnectIQ.IQMessageStatus.FAILURE_DEVICE_NOT_CONNECTED -> Delivery.NOT_CONNECTED
        else -> Delivery.UNKNOWN_FAILURE
    }
}
