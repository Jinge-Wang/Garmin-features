import Toybox.Lang;

// Turns a stored card into drawing runs. Done once, when a card becomes the
// current card; the view then only draws.
module CardCodec {

    // The value of one hex digit (0-9, a-f, A-F).
    function hexValue(ch as Char) as Number {
        var c = ch.toNumber();
        if (c >= 97) {
            return c - 87;
        }
        if (c >= 65) {
            return c - 55;
        }
        return c - 48;
    }

    // One QR row, stored as hex with the leftmost module in the top bit of the
    // first digit, as pairs (first dark column, number of dark columns).
    function rowRuns(hex as String, n as Number) as Array<Number> {
        var digits = hex.toCharArray();
        var runs = [] as Array<Number>;
        var start = -1;
        var value = 0;
        for (var c = 0; c < n; c++) {
            if (c % 4 == 0) {
                var d = c / 4;
                value = d < digits.size() ? hexValue(digits[d]) : 0;
            }
            var dark = ((value >> (3 - c % 4)) & 1) == 1;
            if (dark && start < 0) {
                start = c;
            } else if (!dark && start >= 0) {
                runs.add(start);
                runs.add(c - start);
                start = -1;
            }
        }
        if (start >= 0) {
            runs.add(start);
            runs.add(n - start);
        }
        return runs;
    }

    // All rows of a QR card ("g" in the stored record).
    function qrRows(g as Array, n as Number) as Array<Array<Number> > {
        var rows = [] as Array<Array<Number> >;
        for (var r = 0; r < n && r < g.size(); r++) {
            rows.add(rowRuns(g[r] as String, n));
        }
        return rows;
    }
}
