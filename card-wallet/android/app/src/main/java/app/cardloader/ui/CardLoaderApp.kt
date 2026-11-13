package app.cardloader.ui

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import app.cardloader.codec.Contract
import app.cardloader.codec.Grid
import app.cardloader.codec.ReadOutcome
import app.cardloader.link.WatchState

@Composable
fun CardLoaderApp(model: MainViewModel) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    MaterialTheme(colorScheme = if (dark) darkColorScheme() else lightColorScheme()) {
        Surface(modifier = Modifier.fillMaxSize().safeDrawingPadding(), color = MaterialTheme.colorScheme.background) {
            val watch by model.link.state.collectAsState()
            when (val screen = model.screen) {
                Screen.Home -> HomeScreen(model, watch)
                Screen.Scan -> {
                    BackHandler { model.showHome() }
                    CameraScreen(
                        onRead = model::cameraRead,
                        onBack = model::showHome,
                        onProblem = model::scanFailed,
                    )
                }
                is Screen.Review -> {
                    BackHandler { model.showHome() }
                    ReviewScreen(model, screen.read, watch)
                }
                Screen.Result -> {
                    BackHandler { model.showHome() }
                    ResultScreen(model, watch)
                }
            }
        }
    }
}

@Composable
private fun Page(title: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(title, style = MaterialTheme.typography.headlineMedium)
        content()
    }
}

@Composable
private fun HomeScreen(model: MainViewModel, watch: WatchState) {
    val context = LocalContext.current
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> model.pickedPicture(uri) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) model.openScan() else model.scanFailed("The camera permission was not given. You can pick a picture instead.")
    }
    Page("Card Loader") {
        val status = Texts.watchStatus(watch)
        Text(status.title, style = MaterialTheme.typography.titleLarge)
        status.detail?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
        if (watch is WatchState.Ready && watch.devices.size > 1) {
            Text("Watches known to Garmin Connect", style = MaterialTheme.typography.labelLarge)
            for (device in watch.devices) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .selectable(selected = device.id == watch.selectedId, role = Role.RadioButton, onClick = { model.selectWatch(device.id) }),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = device.id == watch.selectedId, onClick = null)
                    Text(device.name, modifier = Modifier.padding(start = 12.dp, top = 8.dp, bottom = 8.dp))
                }
            }
        }
        TextButton(onClick = { model.refreshWatch() }) { Text("Check the watch again") }

        Spacer(Modifier.height(8.dp))
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = !model.busy,
            onClick = {
                model.clearNotice()
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                    model.openScan()
                } else {
                    permission.launch(Manifest.permission.CAMERA)
                }
            },
        ) { Text("Scan with the camera") }
        OutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            enabled = !model.busy,
            onClick = {
                model.clearNotice()
                picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            },
        ) { Text("Pick a picture") }
        if (model.busy) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp))
                Text("Reading the picture")
            }
        }
        model.notice?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        Text(
            "The code is read on this phone and kept in memory only. It is sent to the watch through Garmin Connect. This app has no network access.",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

@Composable
private fun ReviewScreen(model: MainViewModel, read: ReadOutcome, watch: WatchState) {
    Page("Review") {
        when (read) {
            is ReadOutcome.Qr -> {
                val n = read.symbol.n
                Text(Texts.qrSummary(n))
                Text(Texts.qrOnWatch(n))
                Texts.qrWarning(n)?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                SymbolDrawing(read.symbol.grid)
            }
            is ReadOutcome.Bar -> {
                Text(Texts.barSummary(read.content, read.symbology))
                Text("Content: ${read.content}", style = MaterialTheme.typography.bodyLarge)
                Text(Texts.barOnWatch(read.content))
                Texts.barNote(read.isCode128)?.let { Text(it) }
            }
            else -> Unit
        }
        val clean = Contract.cleanName(model.name)
        val problem = Contract.nameProblem(clean)
        OutlinedTextField(
            value = model.name,
            onValueChange = { model.name = it.replace("\n", "") },
            label = { Text("Name on the watch") },
            singleLine = true,
            isError = model.name.isNotEmpty() && problem != null,
            supportingText = { Text(if (model.name.isNotEmpty() && problem != null) problem else "A card with the same name on the watch is replaced.") },
            modifier = Modifier.fillMaxWidth(),
        )
        val selected = (watch as? WatchState.Ready)?.selected
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = problem == null && selected != null,
            onClick = { selected?.let { model.send(it.id) } },
        ) { Text("Send to watch") }
        if (selected == null) Text(Texts.watchStatus(watch).title)
        TextButton(onClick = { model.showHome() }) { Text("Cancel") }
    }
}

/** The symbol as it will be sent, with a white border of two modules. */
@Composable
private fun SymbolDrawing(grid: Grid) {
    val n = grid.size
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(300.dp),
    ) {
        val side = minOf(size.width, size.height)
        val cell = side / (n + 4)
        val left = (size.width - side) / 2
        drawRect(Color.White, topLeft = Offset(left, 0f), size = Size(side, side))
        for (r in 0 until n) for (c in 0 until n) {
            if (grid[r][c]) {
                drawRect(Color.Black, topLeft = Offset(left + (c + 2) * cell, (r + 2) * cell), size = Size(cell + 0.5f, cell + 0.5f))
            }
        }
    }
}

@Composable
private fun ResultScreen(model: MainViewModel, watch: WatchState) {
    Page("Sending") {
        val progress = model.progress
        if (progress != null) {
            for (line in Texts.resultLines(progress)) {
                val mark = when (line.mark) {
                    Texts.Mark.DONE -> "Done"
                    Texts.Mark.WAITING -> "Waiting"
                    Texts.Mark.FAILED -> "Problem"
                }
                Column {
                    Text(mark, style = MaterialTheme.typography.labelMedium)
                    Text(
                        line.text,
                        color = if (line.mark == Texts.Mark.FAILED) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onBackground,
                    )
                }
            }
        }
        val selected = (watch as? WatchState.Ready)?.selected
        OutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            enabled = selected != null,
            onClick = { selected?.let { model.openWidget(it.id) } },
        ) { Text("Ask the watch to open the widget") }
        model.openNote?.let { Text(it) }
        Button(modifier = Modifier.fillMaxWidth(), onClick = { model.showHome() }) { Text("Done") }
    }
}
