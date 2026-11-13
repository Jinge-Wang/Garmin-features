import Toybox.Application.Storage;
import Toybox.Lang;

// The two choices made on the setup screen. They are kept in the app's
// storage so the next ride starts from the same choice.
class VibeModel {

    var intervalIx as Number = 1;   // index into Cues.INTERVALS; 30 s
    var set as Number = 0;          // 0 is set A, 1 is set B

    function initialize() {
        var ix = Storage.getValue("ix");
        if (ix instanceof Number && ix >= 0 && ix < Cues.INTERVALS.size()) {
            intervalIx = ix;
        }
        var s = Storage.getValue("set");
        if (s instanceof Number && (s == 0 || s == 1)) {
            set = s;
        }
    }

    function interval() as Number {
        return Cues.INTERVALS[intervalIx] as Number;
    }

    // Move to the next (+1) or previous (-1) interval, wrapping round.
    function stepInterval(by as Number) as Void {
        var n = Cues.INTERVALS.size();
        intervalIx = (intervalIx + by + n) % n;
        save();
    }

    function toggleSet() as Void {
        set = 1 - set;
        save();
    }

    private function save() as Void {
        Storage.setValue("ix", intervalIx);
        Storage.setValue("set", set);
    }
}
