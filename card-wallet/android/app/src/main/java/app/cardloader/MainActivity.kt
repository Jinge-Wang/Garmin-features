package app.cardloader

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import app.cardloader.ui.CardLoaderApp
import app.cardloader.ui.MainViewModel

class MainActivity : ComponentActivity() {
    private val model: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { CardLoaderApp(model) }
    }

    override fun onDestroy() {
        // A rotation keeps the model (and the link); closing the activity ends the link.
        if (isFinishing) model.shutdown()
        super.onDestroy()
    }
}
