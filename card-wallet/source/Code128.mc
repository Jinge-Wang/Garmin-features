import Toybox.Lang;
import Toybox.Math;

// Code 128 on the watch: one encoder for every bar-code card, whether it was
// typed on the watch or imported from the built-in list.
//
// A bar code is stored as a String of digits, the width of each bar and gap in
// modules, alternating dark, light, dark ... and starting dark.
// tools/code128_check.swift reads PATTERNS out of this file and checks it.
module Code128 {

    // Symbol values 0..105, then the stop pattern (seven widths). Each pattern
    // is the widths of bar, space, bar, space, bar, space. Entries are 7
    // characters apart: six digits and a space, so entry v starts at v * 7.
    const PATTERNS = "212222 222122 222221 121223 121322 131222 122213 122312 132212 221213 221312 231212 112232 122132 122231 113222 123122 123221 223211 221132 221231 213212 223112 312131 311222 321122 321221 312212 322112 322211 212123 212321 232121 111323 131123 131321 112313 132113 132311 211313 231113 231311 112133 112331 132131 113123 113321 133121 313121 211331 231131 213113 213311 213131 311123 311321 331121 312113 312311 332111 314111 221411 431111 111224 111422 121124 121421 141122 141221 112214 112412 122114 122411 142112 142211 241211 221114 413111 241112 134111 111242 121142 121241 114212 124112 124211 411212 421112 421211 212141 214121 412121 111143 111341 131141 114113 114311 411113 411311 113141 114131 311141 411131 211412 211214 211232 2331112";

    const START_B = 104;
    const START_C = 105;
    const SWITCH_C = 99;
    const STOP = 106;

    // Height of the bars on the watch, in pixels.
    const BAR_HEIGHT = 72;

    // The widths of the Code 128 symbol for text, or null when it cannot be
    // coded: empty, or a character outside ASCII 32 to 126.
    //   all digits, even length: code set C, two digits per symbol
    //   all digits, odd length:  set B for the first digit, then C for pairs
    //   anything else:           set B for every character
    function encode(text as String) as String? {
        var chars = text.toCharArray();
        var n = chars.size();
        if (n == 0) {
            return null;
        }
        var codes = new Array<Number>[n];
        var digits = true;
        for (var i = 0; i < n; i++) {
            var c = chars[i].toNumber();
            if (c < 32 || c > 126) {
                return null;
            }
            if (c < 48 || c > 57) {
                digits = false;
            }
            codes[i] = c;
        }

        var symbols = [] as Array<Number>;
        if (digits) {
            var from = 0;
            if (n % 2 == 0) {
                symbols.add(START_C);
            } else {
                symbols.add(START_B);
                symbols.add(codes[0] - 32);
                from = 1;
                if (n > 1) {
                    symbols.add(SWITCH_C);
                }
            }
            for (var i = from; i + 1 < n; i += 2) {
                symbols.add((codes[i] - 48) * 10 + (codes[i + 1] - 48));
            }
        } else {
            symbols.add(START_B);
            for (var i = 0; i < n; i++) {
                symbols.add(codes[i] - 32);
            }
        }

        // The check symbol: the start value plus each later symbol times its
        // position, modulo 103.
        var sum = symbols[0];
        for (var i = 1; i < symbols.size(); i++) {
            sum += i * symbols[i];
        }
        symbols.add(sum % 103);

        var out = "";
        for (var i = 0; i < symbols.size(); i++) {
            var at = symbols[i] * 7;
            out += PATTERNS.substring(at, at + 6) as String;
        }
        out += PATTERNS.substring(STOP * 7, STOP * 7 + 7) as String;
        return out;
    }

    // The width of the whole code in modules (no quiet zone).
    function moduleCount(widths as String) as Number {
        var chars = widths.toCharArray();
        var total = 0;
        for (var i = 0; i < chars.size(); i++) {
            total += chars[i].toNumber() - 48;
        }
        return total;
    }

    // The widths as numbers, for drawing.
    function widthList(widths as String) as Array<Number> {
        var chars = widths.toCharArray();
        var out = new Array<Number>[chars.size()];
        for (var i = 0; i < out.size(); i++) {
            out[i] = chars[i].toNumber() - 48;
        }
        return out;
    }

    // Pixels per module on a round screen of the given width, with the bars
    // centered and BAR_HEIGHT tall. chord is the screen's width at the top edge
    // of the bars; 8 px stay clear, and 6 modules are the quiet zone (three on
    // each side). 0 means the code is too long to show.
    function modulePx(modules as Number, screenWidth as Number) as Number {
        var r = screenWidth / 2.0f;
        var half = BAR_HEIGHT / 2.0f;
        var chord = 2.0f * Math.sqrt(r * r - half * half);
        var px = Math.floor((chord - 8.0f) / (modules + 6)).toNumber();
        return px;
    }
}
