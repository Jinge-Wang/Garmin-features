package app.cardloader.ui

import android.app.Application
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import app.cardloader.codec.BarCard
import app.cardloader.codec.CodeReader
import app.cardloader.codec.Contract
import app.cardloader.codec.QrCard
import app.cardloader.codec.ReadOutcome
import app.cardloader.link.OpenResult
import app.cardloader.link.Scheduler
import app.cardloader.link.SendController
import app.cardloader.link.SendProgress
import app.cardloader.link.WatchLink
import app.cardloader.link.WatchLinks
import java.util.concurrent.Executors

sealed interface Screen {
    data object Home : Screen
    data object Scan : Screen

    /** `read` is a QR or a bar code outcome. */
    class Review(val read: ReadOutcome) : Screen
    data object Result : Screen
}

/**
 * The state of the app, in memory only: the code that was read lives here until the user leaves
 * the review or the result, and is never written anywhere.
 */
class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    val link: WatchLink = WatchLinks.factory(application)

    var screen by mutableStateOf<Screen>(Screen.Home); private set
    var notice by mutableStateOf<String?>(null); private set
    var busy by mutableStateOf(false); private set
    var name by mutableStateOf("")
    var progress by mutableStateOf<SendProgress?>(null); private set
    var openNote by mutableStateOf<String?>(null); private set

    private val scheduler = object : Scheduler {
        private val pending = ArrayList<Runnable>()
        override fun postDelayed(delayMs: Long, action: () -> Unit) {
            val r = Runnable { action() }
            pending.add(r)
            main.postDelayed(r, delayMs)
        }

        override fun cancelAll() {
            pending.forEach { main.removeCallbacks(it) }
            pending.clear()
        }
    }
    private val controller = SendController(link, scheduler, { progress = it })
    private var shutDown = false

    init {
        link.start()
    }

    fun refreshWatch() = link.refresh()
    fun selectWatch(id: Long) = link.select(id)

    fun showHome() {
        controller.stop()
        openNote = null
        name = ""
        screen = Screen.Home
    }

    fun clearNotice() {
        notice = null
    }

    fun openScan() {
        notice = null
        screen = Screen.Scan
    }

    fun scanFailed(message: String) {
        notice = message
        screen = Screen.Home
    }

    /** From the camera: a good read goes to the review; anything else is only a hint on the scan screen. */
    fun cameraRead(outcome: ReadOutcome) {
        if (outcome is ReadOutcome.Qr || outcome is ReadOutcome.Bar) {
            name = ""
            screen = Screen.Review(outcome)
        }
    }

    fun pickedPicture(uri: Uri?) {
        if (uri == null) return
        notice = null
        busy = true
        val resolver = getApplication<Application>().contentResolver
        worker.execute {
            val picture = PictureLoader.load(resolver, uri)
            val outcome = if (picture == null) null else CodeReader.read(picture, thorough = true)
            main.post {
                busy = false
                when {
                    outcome == null -> notice = "That picture could not be opened."
                    outcome is ReadOutcome.Qr || outcome is ReadOutcome.Bar -> {
                        name = ""
                        screen = Screen.Review(outcome)
                    }
                    else -> notice = Texts.notice(outcome)
                }
            }
        }
    }

    fun send(selectedWatch: Long) {
        val review = screen as? Screen.Review ?: return
        val clean = Contract.cleanName(name)
        if (Contract.nameProblem(clean) != null) return
        val card = when (val read = review.read) {
            is ReadOutcome.Qr -> QrCard.of(clean, read.symbol.grid)
            is ReadOutcome.Bar -> BarCard(clean, read.content)
            else -> return
        }
        openNote = null
        controller.start(card, selectedWatch)
        screen = Screen.Result
    }

    fun openWidget(selectedWatch: Long) {
        openNote = null
        controller.openWidget(selectedWatch) { result: OpenResult -> openNote = Texts.openResult(result) }
    }

    fun shutdown() {
        if (shutDown) return
        shutDown = true
        controller.stop()
        link.shutdown()
        worker.shutdown()
    }

    override fun onCleared() {
        shutdown()
    }
}
