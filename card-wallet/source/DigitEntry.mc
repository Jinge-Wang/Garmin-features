import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Typing the number of a bar code. UP and DOWN go through 0 to 9 and "OK",
// START picks the shown item, BACK deletes the last digit (or leaves when
// nothing is typed). The digits typed so far are shown, wrapped.
class DigitView extends WatchUi.View {

    private const MAX_DIGITS = 36;
    private const LINE = 12;
    private const OK = 10;

    private var _digits as String = "";
    private var _pos as Number = 0;
    private var _message as String = "";

    function initialize() {
        View.initialize();
    }

    function digits() as String {
        return _digits;
    }

    function move(by as Number) as Void {
        _pos = (_pos + by + OK + 1) % (OK + 1);
        _message = "";
        WatchUi.requestUpdate();
    }

    // START: types the shown digit. On "OK" returns true when the number is
    // complete and fits the screen; otherwise the view shows why not.
    function pick() as Boolean {
        _message = "";
        if (_pos < OK) {
            if (_digits.length() < MAX_DIGITS) {
                _digits = _digits + _pos.toString();
            } else {
                _message = "Longest number";
            }
        } else if (_digits.length() == 0) {
            _message = "Type digits first";
        } else {
            var widths = Code128.encode(_digits);
            var px = widths == null ? 0 : Code128.modulePx(Code128.moduleCount(widths), System.getDeviceSettings().screenWidth);
            if (px < 1) {
                _message = "Too long to show";
            } else {
                return true;
            }
        }
        WatchUi.requestUpdate();
        return false;
    }

    // BACK: removes the last digit; false when nothing was typed.
    function back() as Boolean {
        if (_digits.length() == 0) {
            return false;
        }
        _digits = _digits.substring(0, _digits.length() - 1) as String;
        _message = "";
        WatchUi.requestUpdate();
        return true;
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var font = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(font);

        // The digits typed so far, wrapped, with a cursor.
        var shown = _digits + "_";
        var y = 36;
        for (var at = 0; at < shown.length(); at += LINE) {
            var end = at + LINE < shown.length() ? at + LINE : shown.length();
            dc.drawText(width / 2, y, font, shown.substring(at, end) as String, Graphics.TEXT_JUSTIFY_CENTER);
            y += fh;
        }

        // The item START would pick.
        // The number fonts hold digits only, so "OK" is drawn in a text font.
        var label = _pos < OK ? _pos.toString() : "OK";
        dc.drawText(width / 2, height / 2, _pos < OK ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_LARGE, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, height - 2 * fh - 24, font, "UP/DOWN  START picks", Graphics.TEXT_JUSTIFY_CENTER);
        if (_message.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2 + 36, font, _message, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class DigitDelegate extends WatchUi.BehaviorDelegate {

    private var _entry as DigitView;
    private var _cards as CardView;
    private var _store as CardStore;

    function initialize(entry as DigitView, cards as CardView, store as CardStore) {
        BehaviorDelegate.initialize();
        _entry = entry;
        _cards = cards;
        _store = store;
    }

    function onNextPage() as Boolean {
        _entry.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _entry.move(-1);
        return true;
    }

    function onSelect() as Boolean {
        if (_entry.pick()) {
            var digits = _entry.digits();
            var widths = Code128.encode(digits) as String;
            WatchUi.switchToView(new WatchUi.TextPicker("Card " + (_store.count() + 1).toString()),
                new AddDelegate(_cards, _store, digits, widths), WatchUi.SLIDE_IMMEDIATE);
        }
        return true;
    }

    function onBack() as Boolean {
        if (_entry.back()) {
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
