import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Setup screen: the interval and the pattern set. Black on white like the
// other screens.
class SetupView extends WatchUi.View {

    private var _model as VibeModel;

    function initialize(model as VibeModel) {
        View.initialize();
        _model = model;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var c = Graphics.TEXT_JUSTIFY_CENTER;
        dc.drawText(cx, 18, Graphics.FONT_SMALL, "Vibe test", c);
        dc.drawText(cx, 55, Graphics.FONT_LARGE, "Every " + _model.interval() + " s", c);
        dc.drawText(cx, 105, Graphics.FONT_LARGE, "Set " + Cues.setName(_model.set), c);
        var hint = _model.set == 0 ? "L long, R 3 short" : "L 2 medium, R 4 short";
        dc.drawText(cx, 150, Graphics.FONT_XTINY, hint, c);
        dc.drawText(cx, 185, Graphics.FONT_XTINY, "UP/DOWN: interval", c);
        dc.drawText(cx, 208, Graphics.FONT_XTINY, "Hold UP: set, last run", c);
        dc.drawText(cx, 232, Graphics.FONT_XTINY, "START: begin", c);
    }
}
