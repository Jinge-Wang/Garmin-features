import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// A build for looking at the screens without pressing buttons: the app's own
// code plus a timer that presses the buttons in a fixed order and prints
// "step N ..." after each press. Never part of the app: only check.jungle
// adds this folder, and the check build has its own app id and storage.
class CheckVibeApp extends VibeApp {

    private var _timer as Timer.Timer?;
    private var _step as Number = 0;
    private var _model as VibeModel?;
    private var _setup as SetupDelegate?;

    function initialize() {
        VibeApp.initialize();
    }

    (:typecheck(false))
    function getInitialView() {
        Storage.clearValues();
        var model = new VibeModel();
        _model = model;
        _setup = new SetupDelegate(model);
        _timer = new Timer.Timer();
        _timer.start(method(:onStep), 3000, true);
        System.println("step 0 setup screen");
        return [new SetupView(model), _setup];
    }

    (:typecheck(false))
    private function top() {
        var current = WatchUi.getCurrentView();
        return current == null ? null : current[1];
    }

    (:typecheck(false))
    function onStep() as Void {
        _step++;
        var s = _step;
        var what = "";
        if (s == 1) {
            _setup.onPreviousPage();
            what = "UP: interval now " + _model.interval() + " s";
        } else if (s == 2) {
            _setup.onMenu();
            what = "menu";
        } else if (s == 3) {
            new SetupMenuDelegate(_model).onSelect(new WatchUi.MenuItem("Pattern set", "A", :set, {}));
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            what = "pattern set now " + Cues.setName(_model.set) + ", menu closed";
        } else if (s == 4) {
            _setup.onSelect();
            what = "run started";
        } else if (s == 5) {
            top().onSelect();
            what = "START fired a cue";
        } else if (s < 13) {
            what = "waiting for the timed cue";
        } else if (s == 13) {
            top().onBack();
            what = "run ended, summary";
        } else if (s == 14) {
            _setup.onMenu();
            new SetupMenuDelegate(_model).onSelect(new WatchUi.MenuItem("Last run", null, :last, {}));
            what = "last run from the menu";
        } else {
            _timer.stop();
            System.println("step " + s + " done");
            return;
        }
        System.println("step " + s + " " + what);
    }
}
