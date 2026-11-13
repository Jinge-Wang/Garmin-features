import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// BACK leaves the summary. After a run that leaves the app; from the setup
// menu it returns to the menu.
class SummaryDelegate extends WatchUi.BehaviorDelegate {

    private var _exit as Boolean;

    function initialize(exitApp as Boolean) {
        BehaviorDelegate.initialize();
        _exit = exitApp;
    }

    function onBack() as Boolean {
        if (_exit) {
            System.exit();
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
