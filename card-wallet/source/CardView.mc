import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// One card, full screen: black code on white, the card's name above it.
// A card is decoded into drawing runs once, when it becomes the current card;
// onUpdate only draws them.
class CardView extends WatchUi.View {

    private const NONE = 0;
    private const QR = 1;
    private const BAR = 2;

    private var _store as CardStore;
    private var _index as Number = 0;

    // The decoded current card.
    private var _kind as Number = 0;
    private var _name as String = "";
    private var _n as Number = 0;                         // QR: modules per side
    private var _rows as Array<Array<Number> > = [] as Array<Array<Number> >;   // QR: runs per row
    private var _widths as Array<Number> = [] as Array<Number>;                 // bar: module widths
    private var _modules as Number = 0;                   // bar: total modules
    private var _text as String = "";                     // bar: the typed content
    private var _note as String = "";

    function initialize(store as CardStore) {
        View.initialize();
        _store = store;
        load();
    }

    function onShow() as Void {
        lightOn();
    }

    // A lit screen is easier for a scanner in a dim entrance. The light goes
    // off on the watch's own timer; START turns it on again.
    function lightOn() as Void {
        if (Attention has :backlight) {
            try {
                Attention.backlight(true);
            } catch (e) {
                // The watch refused; the code is still readable by reflection.
            }
        }
    }

    function index() as Number {
        return _index;
    }

    // A short message under the code, until the next button press.
    function setNote(text as String) as Void {
        _note = text;
        WatchUi.requestUpdate();
    }

    // Decodes the card at the current position.
    private function load() as Void {
        _kind = NONE;
        _rows = [] as Array<Array<Number> >;
        _widths = [] as Array<Number>;
        var rec = _store.record(_index);
        if (rec == null) {
            return;
        }
        _name = rec["name"] as String;
        var kind = rec["kind"] as String?;
        if ("bar".equals(kind)) {
            var text = rec["t"] as String;
            var b = rec["b"];
            var widths = b != null ? b as String : Code128.encode(text);
            if (widths != null) {
                _text = text;
                _widths = Code128.widthList(widths);
                _modules = Code128.moduleCount(widths);
                _kind = BAR;
            }
        } else if ("qr".equals(kind)) {
            _n = rec["n"] as Number;
            _rows = CardCodec.qrRows(rec["g"] as Array, _n);
            _kind = QR;
        }
    }

    // Shows the card at a position (after adding one).
    function showIndex(index as Number) as Void {
        var count = _store.count();
        _index = count == 0 ? 0 : (index < 0 ? 0 : (index >= count ? count - 1 : index));
        _note = "";
        load();
        WatchUi.requestUpdate();
    }

    // Reloads the current card after a rename or a delete.
    function reload() as Void {
        showIndex(_index);
    }

    // Move to the next (+1) or previous (-1) card.
    function step(by as Number) as Void {
        var count = _store.count();
        _note = "";
        if (count < 2) {
            return;
        }
        _index = (_index + by + count) % count;
        load();
        lightOn();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        var font = Graphics.FONT_XTINY;
        var fontHeight = dc.getFontHeight(font);
        var count = _store.count();
        if (count == 0 || _kind == NONE) {
            var line = count == 0 ? "No cards" : "Cannot show this card";
            dc.drawText(width / 2, height / 2 - fontHeight, Graphics.FONT_SMALL, line,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(width / 2, height / 2 + fontHeight, font, "Hold UP for menu",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var pageTop = 0;
        if (_kind == QR) {
            // The code sits in the square that fits inside the round screen,
            // with one module of margin on each side. tools/cardtool.swift
            // uses the same arithmetic for its preview.
            var shorter = width < height ? width : height;
            var px = (shorter * 707 / 1000) / (_n + 2);
            if (px < 1) {
                px = 1;
            }
            var side = px * _n;
            var left = (width - side) / 2;
            var top = (height - side) / 2;
            for (var r = 0; r < _rows.size(); r++) {
                var runs = _rows[r];
                var y = top + r * px;
                for (var k = 0; k + 1 < runs.size(); k += 2) {
                    dc.fillRectangle(left + runs[k] * px, y, runs[k + 1] * px, px);
                }
            }
            // Labels keep two modules clear of the code so that a scanner
            // still sees a white border around it.
            var nameTop = top - 2 * px - fontHeight;
            if (nameTop >= 8) {
                dc.drawText(width / 2, nameTop, font, _name, Graphics.TEXT_JUSTIFY_CENTER);
            }
            pageTop = top + side + 2 * px;
        } else {
            // Bars Code128.BAR_HEIGHT tall, centered. The module width is the
            // largest whole number of pixels that fits the screen's width at
            // the top of the bars, with three modules of white on each side.
            var px = Code128.modulePx(_modules, width);
            var barTop = (height - Code128.BAR_HEIGHT) / 2;
            dc.drawText(width / 2, barTop - fontHeight - 6, font, _name, Graphics.TEXT_JUSTIFY_CENTER);
            if (px < 1) {
                dc.drawText(width / 2, height / 2, font, "Code too long", Graphics.TEXT_JUSTIFY_CENTER);
                return;
            }
            var x = (width - _modules * px) / 2;
            for (var k = 0; k < _widths.size(); k++) {
                var w = _widths[k] * px;
                if (k % 2 == 0) {
                    dc.fillRectangle(x, barTop, w, Code128.BAR_HEIGHT);
                }
                x += w;
            }
            // The content under the bars, in lines of at most 20 characters.
            var y = barTop + Code128.BAR_HEIGHT + 6;
            var at = 0;
            while (at < _text.length() && y < height - 2 * fontHeight - 16) {
                var end = at + 20 < _text.length() ? at + 20 : _text.length();
                dc.drawText(width / 2, y, font, _text.substring(at, end) as String, Graphics.TEXT_JUSTIFY_CENTER);
                y += fontHeight;
                at = end;
            }
            pageTop = y + 4;
        }

        if (count > 1 && pageTop + fontHeight <= height - 30) {
            dc.drawText(width / 2, pageTop, font, (_index + 1).format("%d") + " / " + count.format("%d"),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (_note.length() > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height - fontHeight - 24, font, _note, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
