import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The entry in the widget list: the title and the names of the cards. It
// reads only the list of names; it never loads a card.
(:glance)
class CardsGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height / 4, Graphics.FONT_GLANCE, "CARDS",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(0, height * 3 / 4, Graphics.FONT_GLANCE, namesText(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // The names joined by ", "; empty before the first full launch.
    private function namesText() as String {
        var names = Storage.getValue("names");
        var text = "";
        if (names != null) {
            var list = names as Array;
            for (var i = 0; i < list.size(); i++) {
                text += (i > 0 ? ", " : "") + (list[i] as String);
            }
        }
        return text;
    }
}
