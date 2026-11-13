package app.cardloader

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** Starts the real activity with the real Connect IQ SDK and no Garmin Connect app on the "phone". */
@RunWith(RobolectricTestRunner::class)
class HomeScreenTest {
    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    @Test
    fun homeSaysThatGarminConnectIsMissing() {
        rule.waitForIdle()
        rule.onNodeWithText("Garmin Connect is not installed").assertExists()
        rule.onNodeWithText("Scan with the camera").assertExists()
        rule.onNodeWithText("Pick a picture").assertExists()
    }
}
