import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// The running screen. One 1-second timer checks the clock; a cue is fired
// when the next cue time has come. Times are wall-clock seconds, so a late
// tick does not make the schedule drift.
class RunView extends WatchUi.View {

    private var _interval as Number;
    private var _set as Number;
    private var _timer as Timer.Timer;
    private var _startSec as Number;
    private var _nextSec as Number;
    private var _fired as Number = 0;
    private var _last as String = "";     // "L", "R" or "" before the first cue
    private var _seq as String = "";

    function initialize(interval as Number, set as Number) {
        View.initialize();
        _interval = interval;
        _set = set;
        _startSec = Time.now().value();
        _nextSec = _startSec + interval;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    // Once a second: fire the cue if its time has come, redraw.
    function onTick() as Void {
        if (Time.now().value() >= _nextSec) {
            fire();
        }
        WatchUi.requestUpdate();
    }

    // Fire the next cue of the fixed order and schedule the one after it.
    function fire() as Void {
        var now = Time.now().value();
        var side = Cues.letter(_fired);
        Cues.play(_set, side);
        System.println((now - _startSec) + " s " + side + " set " + Cues.setName(_set));
        _last = side;
        _seq = _seq + side;
        _fired++;
        _nextSec = now + _interval;
        WatchUi.requestUpdate();
    }

    // Stop the timer and return the summary of the run.
    function finish() as Dictionary {
        _timer.stop();
        return {
            "dur" => Time.now().value() - _startSec,
            "n" => _fired,
            "iv" => _interval,
            "set" => Cues.setName(_set),
            "seq" => _seq
        };
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var w = dc.getWidth();
        var cx = w / 2;
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var left = _nextSec - Time.now().value();
        if (left < 0) {
            left = 0;
        }
        dc.drawText(cx, 24, Graphics.FONT_MEDIUM, "Next in " + left + " s", c);
        if (_last.equals("")) {
            dc.drawText(cx, 110, Graphics.FONT_LARGE, "Ready", c);
        } else {
            dc.fillPolygon(arrow(_last.equals("L"), cx, 140));
        }
        dc.drawText(cx, 212, Graphics.FONT_MEDIUM, "Cues " + _fired + "  Set " + Cues.setName(_set), c);
    }

    // An arrow 180 px long and 120 px tall, centred on (cx, cy).
    private function arrow(toLeft as Boolean, cx as Number, cy as Number) as Array<[Numeric, Numeric]> {
        var d = toLeft ? 1 : -1;     // +1 draws the point on the left
        return [
            [cx - d * 90, cy],
            [cx - d * 20, cy - 60],
            [cx - d * 20, cy - 24],
            [cx + d * 90, cy - 24],
            [cx + d * 90, cy + 24],
            [cx - d * 20, cy + 24],
            [cx - d * 20, cy + 60]
        ] as Array<[Numeric, Numeric]>;
    }
}
