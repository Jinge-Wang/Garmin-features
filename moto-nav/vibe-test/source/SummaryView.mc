import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The summary of a run: duration, cues, interval, set and the letters fired.
class SummaryView extends WatchUi.View {

    private var _s as Dictionary?;
    private var _justEnded as Boolean;

    function initialize(summary as Dictionary?, justEnded as Boolean) {
        View.initialize();
        _s = summary;
        _justEnded = justEnded;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        var s = _s;
        if (s == null) {
            dc.drawText(cx, 100, Graphics.FONT_MEDIUM, "No run yet", c);
            return;
        }
        var dur = s["dur"] as Number;
        var n = s["n"] as Number;
        var seq = s["seq"] as String;
        dc.drawText(cx, 20, Graphics.FONT_SMALL, _justEnded ? "Run ended" : "Last run", c);
        dc.drawText(cx, 52, Graphics.FONT_MEDIUM, (dur / 60) + " min " + (dur % 60) + " s", c);
        dc.drawText(cx, 88, Graphics.FONT_MEDIUM, n + " cues, " + (s["iv"] as Number) + " s", c);
        dc.drawText(cx, 122, Graphics.FONT_MEDIUM, "Set " + (s["set"] as String), c);
        // The letters in groups of six, two groups to a line, at most three
        // lines (36 letters); the rest is counted.
        var y = 158;
        var shown = n < 36 ? n : 36;
        for (var i = 0; i < shown; i += 12) {
            var end = i + 12 < shown ? i + 12 : shown;
            dc.drawText(cx, y, Graphics.FONT_XTINY, group(seq.substring(i, end) as String), c);
            y += 22;
        }
        if (n > 36) {
            dc.drawText(cx, y, Graphics.FONT_XTINY, "+ " + (n - 36) + " more", c);
        }
    }

    // "LRRLLRLRR" becomes "LRRLLR LRR".
    private function group(t as String) as String {
        if (t.length() <= 6) {
            return t;
        }
        return (t.substring(0, 6) as String) + " " + (t.substring(6, t.length()) as String);
    }
}
