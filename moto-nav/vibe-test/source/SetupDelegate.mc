import Toybox.Lang;
import Toybox.WatchUi;

// UP and DOWN change the interval; a long press of UP opens the menu; START
// begins the run.
class SetupDelegate extends WatchUi.BehaviorDelegate {

    private var _model as VibeModel;

    function initialize(model as VibeModel) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    function onNextPage() as Boolean {
        _model.stepInterval(1);
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        _model.stepInterval(-1);
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Boolean {
        var view = new RunView(_model.interval(), _model.set);
        WatchUi.pushView(view, new RunDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    // Long press of UP: the pattern set and the last run.
    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => "Vibe test"});
        menu.addItem(new WatchUi.MenuItem("Pattern set", Cues.setName(_model.set), :set, {}));
        menu.addItem(new WatchUi.MenuItem("Last run", null, :last, {}));
        WatchUi.pushView(menu, new SetupMenuDelegate(_model), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

// The menu: "Pattern set" flips between A and B and stays open; "Last run"
// shows the stored summary.
class SetupMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _model as VibeModel;

    function initialize(model as VibeModel) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :set) {
            _model.toggleSet();
            item.setSubLabel(Cues.setName(_model.set));
            WatchUi.requestUpdate();
        } else if (id == :last) {
            var view = new SummaryView(Summary.load(), false);
            WatchUi.pushView(view, new SummaryDelegate(false), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
