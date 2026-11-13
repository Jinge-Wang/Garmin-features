import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Vibe test: fires left and right vibration cues on a timer so the rider can
// judge by feel which patterns can be felt and told apart on a motorcycle.
// The app has no permissions, no GPS and no sensors.
class VibeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        var model = new VibeModel();
        return [new SetupView(model), new SetupDelegate(model)];
    }
}
