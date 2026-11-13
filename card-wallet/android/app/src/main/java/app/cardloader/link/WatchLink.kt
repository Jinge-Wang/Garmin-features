package app.cardloader.link

import kotlinx.coroutines.flow.StateFlow

enum class DeviceState { NOT_PAIRED, NOT_CONNECTED, CONNECTED, UNKNOWN }

data class WatchDevice(val id: Long, val name: String, val state: DeviceState)

/** What the phone knows about the watch, as the home screen shows it. */
sealed interface WatchState {
    data object Starting : WatchState
    data object GarminConnectMissing : WatchState
    data object GarminConnectTooOld : WatchState
    data object ServiceError : WatchState

    /** Garmin Connect answered. `devices` is empty when no watch is paired. */
    data class Ready(val devices: List<WatchDevice>, val selectedId: Long?) : WatchState {
        val selected: WatchDevice? get() = devices.firstOrNull { it.id == selectedId }
    }
}

/** What Garmin Connect says about a message that was handed to it (the SDK's message status). */
enum class Delivery {
    SUCCESS, UNKNOWN_FAILURE, INVALID_FORMAT, TOO_LARGE, UNSUPPORTED_TYPE, TRANSFER_FAILED, INVALID_DEVICE,
    NOT_CONNECTED, LINK_ERROR,
}

enum class OpenResult { PROMPT_SHOWN, PROMPT_NOT_SHOWN, NOT_INSTALLED, ALREADY_RUNNING, UNKNOWN_FAILURE, LINK_ERROR }

/**
 * The phone's link to the watch. The only implementation that touches the Connect IQ SDK is
 * ConnectIqWatchLink; the rest of the app and the tests use this interface. Callbacks arrive on
 * the main thread.
 */
interface WatchLink {
    val state: StateFlow<WatchState>

    fun start()
    fun refresh()
    fun select(deviceId: Long)

    /** Calls back with every message the widget sends on this device, until stopListening. */
    fun listen(deviceId: Long, onPayload: (List<Any?>) -> Unit)
    fun stopListening()

    /** Hands the message to Garmin Connect. Returns false when it could not be handed over. */
    fun send(deviceId: Long, message: Map<String, Any>, onDelivery: (Delivery) -> Unit): Boolean

    /** Asks the watch to open the widget; the watch shows a prompt. */
    fun openWidget(deviceId: Long, onResult: (OpenResult) -> Unit)

    fun shutdown()
}

/** Where the app gets its link; a test replaces `factory`. */
object WatchLinks {
    var factory: (android.content.Context) -> WatchLink = { ConnectIqWatchLink(it) }
}
