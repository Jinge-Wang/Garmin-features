package app.cardloader.ui

import android.util.Size
import androidx.activity.ComponentActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import app.cardloader.codec.CodeReader
import app.cardloader.codec.FrameFilter
import app.cardloader.codec.Luma
import app.cardloader.codec.ReadOutcome
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The camera preview with an analysis that reads each frame's luminance plane with ZXing. The
 * first read that FrameFilter takes goes to `onRead` (a QR code at once, a bar code after three
 * equal frames). Frames are not stored.
 */
@Composable
fun CameraScreen(onRead: (ReadOutcome) -> Unit, onBack: () -> Unit, onProblem: (String) -> Unit) {
    val context = LocalContext.current
    val activity = context as ComponentActivity
    val mainExecutor = ContextCompat.getMainExecutor(context)
    var hint by remember { mutableStateOf<String?>(null) }
    val finished = remember { AtomicBoolean(false) }
    val filter = remember { FrameFilter() }
    val analysisExecutor = remember { Executors.newSingleThreadExecutor() }
    var provider by remember { mutableStateOf<ProcessCameraProvider?>(null) }

    DisposableEffect(Unit) {
        onDispose {
            finished.set(true)
            provider?.unbindAll()
            analysisExecutor.shutdown()
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier
                .weight(1f)
                .fillMaxSize(),
            factory = { ctx ->
                val view = PreviewView(ctx)
                val future = ProcessCameraProvider.getInstance(ctx)
                future.addListener({
                    try {
                        val cameraProvider = future.get()
                        provider = cameraProvider
                        val preview = Preview.Builder().build().also { it.setSurfaceProvider(view.surfaceProvider) }
                        val analysis = ImageAnalysis.Builder()
                            .setResolutionSelector(
                                ResolutionSelector.Builder()
                                    .setResolutionStrategy(
                                        ResolutionStrategy(Size(1280, 720), ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER),
                                    )
                                    .build(),
                            )
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                        analysis.setAnalyzer(analysisExecutor) { image ->
                            analyze(image, finished, filter) { outcome ->
                                mainExecutor.execute {
                                    if (outcome is ReadOutcome.Qr || outcome is ReadOutcome.Bar) onRead(outcome)
                                    else hint = Texts.notice(outcome)
                                }
                            }
                        }
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(activity, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                    } catch (e: Exception) {
                        onProblem("The camera could not be started. You can pick a picture instead.")
                    }
                }, mainExecutor)
                view
            },
        )
        Text(
            hint ?: "Point the camera at a QR code or a bar code.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(16.dp),
        )
        TextButton(onClick = onBack, modifier = Modifier.padding(horizontal = 8.dp)) { Text("Cancel") }
    }
}

private fun analyze(image: ImageProxy, finished: AtomicBoolean, filter: FrameFilter, deliver: (ReadOutcome) -> Unit) {
    try {
        if (finished.get()) return
        val plane = image.planes[0]
        val width = image.width
        val height = image.height
        val stride = plane.rowStride
        val buffer = plane.buffer
        val bytes = ByteArray(width * height)
        for (y in 0 until height) {
            buffer.position(y * stride)
            buffer.get(bytes, y * width, width)
        }
        val outcome = CodeReader.read(Luma(width, height, bytes), thorough = false)
        val take = filter.take(outcome)
        when (outcome) {
            ReadOutcome.NotFound -> Unit
            is ReadOutcome.Qr, is ReadOutcome.Bar -> if (take && finished.compareAndSet(false, true)) deliver(outcome)
            else -> deliver(outcome)
        }
    } catch (e: Exception) {
        // A frame that cannot be read is skipped.
    } finally {
        image.close()
    }
}
