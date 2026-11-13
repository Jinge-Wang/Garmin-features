import Toybox.Lang;

// Checks a card sent by the phone and stores it. No transport and no view
// here, so the unit tests can call it. The rules and the `why` codes are the
// phone-link contract (README, "Phone link").
module CardInbox {

    // The result of check(): { "id" => Number, "why" => String, "rec" => Dictionary? }.
    // why is "" when the message is valid; rec is then the record to store,
    // built from the checked fields and never from the received object.
    function check(obj as Object?, screenWidth as Number) as Dictionary {
        var id = 0;
        if (obj instanceof Lang.Dictionary) {
            var raw = (obj as Dictionary)["id"];
            if (raw instanceof Lang.Number && inRange(raw as Number)) {
                id = raw as Number;
            }
        }
        var result = {"id" => id, "why" => "", "rec" => null} as Dictionary;
        if (!(obj instanceof Lang.Dictionary)) {
            result["why"] = "format";
            return result;
        }
        var msg = obj as Dictionary;
        if (!wellFormed(msg, id)) {
            result["why"] = "format";
            return result;
        }
        var name = msg["name"] as String;
        if (!nameOk(name)) {
            result["why"] = "name";
            return result;
        }
        var kind = msg["kind"] as String;
        if (kind.equals("qr")) {
            var why = checkGrid(msg["n"] as Number, msg["g"] as Array);
            if (!why.equals("")) {
                result["why"] = why;
                return result;
            }
            result["rec"] = {"name" => name, "kind" => "qr", "n" => msg["n"] as Number, "g" => msg["g"] as Array};
            return result;
        }
        if (kind.equals("bar")) {
            var t = msg["t"] as String;
            if (!textOk(t)) {
                result["why"] = "content";
                return result;
            }
            var b = Code128.encode(t);
            if (b == null) {
                result["why"] = "content";
                return result;
            }
            if (Code128.modulePx(Code128.moduleCount(b), screenWidth) < 1) {
                result["why"] = "long";
                return result;
            }
            result["rec"] = {"name" => name, "kind" => "bar", "t" => t, "b" => b};
            return result;
        }
        result["why"] = "kind";
        return result;
    }

    // Checks the message and stores the card: a stored card of the same name
    // is replaced in place, otherwise the card is appended. Returns
    // { "answer" => { "id", "ok", "why" }, "index" => position, or -1 }.
    // The answer never holds the name, the grid or the content.
    function accept(obj as Object?, screenWidth as Number, store as CardStore) as Dictionary {
        var result = check(obj, screenWidth);
        var why = result["why"] as String;
        var index = -1;
        if (why.equals("")) {
            var rec = result["rec"] as Dictionary;
            var at = store.indexOfName(rec["name"] as String);
            if (at >= 0) {
                index = store.replace(at, rec) ? at : -1;
            } else {
                index = store.add(rec);
            }
            if (index < 0) {
                why = "full";
            }
        }
        var answer = {"id" => result["id"] as Number, "ok" => why.equals(""), "why" => why};
        return {"answer" => answer, "index" => index} as Dictionary;
    }

    function inRange(id as Number) as Boolean {
        return id >= 1 && id <= 1000000000;
    }

    // "format": v, id, the key set and the type of every value. The key set
    // depends on kind; an unknown kind is left to the "kind" step.
    function wellFormed(msg as Dictionary, id as Number) as Boolean {
        var v = msg["v"];
        if (!(v instanceof Lang.Number) || (v as Number) != 1) {
            return false;
        }
        if (id == 0) {
            return false;
        }
        if (!(msg["name"] instanceof Lang.String) || !(msg["kind"] instanceof Lang.String)) {
            return false;
        }
        var kind = msg["kind"] as String;
        if (kind.equals("qr")) {
            if (!(msg["n"] instanceof Lang.Number) || !(msg["g"] instanceof Lang.Array)) {
                return false;
            }
            var g = msg["g"] as Array;
            for (var i = 0; i < g.size(); i++) {
                if (!(g[i] instanceof Lang.String)) {
                    return false;
                }
            }
            return msg.size() == 6;
        }
        if (kind.equals("bar")) {
            var t = msg["t"];
            if (!(t instanceof Lang.String)) {
                return false;
            }
            return msg.size() == 5;
        }
        return true;
    }

    // 1 to 24 characters, no control character, no space at either end.
    function nameOk(name as String) as Boolean {
        var chars = name.toCharArray();
        var n = chars.size();
        if (n < 1 || n > 24) {
            return false;
        }
        for (var i = 0; i < n; i++) {
            var c = chars[i].toNumber();
            if (c < 32 || c == 127) {
                return false;
            }
        }
        return chars[0].toNumber() != 32 && chars[n - 1].toNumber() != 32;
    }

    // 1 to 80 characters, each ASCII 32 to 126.
    function textOk(t as String) as Boolean {
        var chars = t.toCharArray();
        if (chars.size() < 1 || chars.size() > 80) {
            return false;
        }
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i].toNumber();
            if (c < 32 || c > 126) {
                return false;
            }
        }
        return true;
    }

    // "size", "chars" or "shape" for a QR grid; "" when it is fine.
    function checkGrid(n as Number, g as Array) as String {
        if (n < 21 || n > 177 || (n - 17) % 4 != 0 || g.size() != n) {
            return "size";
        }
        var width = (n + 3) / 4;
        var pad = 4 * width - n;
        for (var r = 0; r < n; r++) {
            if ((g[r] as String).length() != width) {
                return "size";
            }
        }
        for (var r = 0; r < n; r++) {
            var digits = (g[r] as String).toCharArray();
            for (var d = 0; d < width; d++) {
                var c = digits[d].toNumber();
                var value = -1;
                if (c >= 48 && c <= 57) {
                    value = c - 48;
                } else if (c >= 97 && c <= 102) {
                    value = c - 87;
                }
                if (value < 0) {
                    return "chars";
                }
                // The unused low bits of the last digit must be 0.
                if (d == width - 1 && (value & ((1 << pad) - 1)) != 0) {
                    return "chars";
                }
            }
        }
        if (finder(g, 0, 0) && finder(g, 0, n - 7) && finder(g, n - 7, 0) && !finder(g, n - 7, n - 7)) {
            return "";
        }
        return "shape";
    }

    // Is there a position square (7 x 7, dark except the ring at distance 2
    // from the centre) with its top left module at (row, column)?
    function finder(g as Array, row as Number, column as Number) as Boolean {
        for (var r = 0; r < 7; r++) {
            var digits = (g[row + r] as String).toCharArray();
            for (var c = 0; c < 7; c++) {
                var col = column + c;
                var value = CardCodec.hexValue(digits[col / 4]);
                var dark = ((value >> (3 - col % 4)) & 1) == 1;
                var ring = max((r - 3).abs(), (c - 3).abs());
                if (dark != (ring != 2)) {
                    return false;
                }
            }
        }
        return true;
    }

    function max(a as Number, b as Number) as Number {
        return a > b ? a : b;
    }
}
