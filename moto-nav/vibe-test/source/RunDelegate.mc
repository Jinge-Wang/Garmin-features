import Toybox.Lang;
import Toybox.WatchUi;

// START fires the next cue now; BACK ends the run and shows the summary.
class RunDelegate extends WatchUi.BehaviorDelegate {

    private var _view as RunView;

    function initialize(view as RunView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.fire();
        return true;
    }

    function onBack() as Boolean {
        var result = _view.finish();
        Summary.save(result);
        WatchUi.switchToView(new SummaryView(result, true), new SummaryDelegate(true), WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
