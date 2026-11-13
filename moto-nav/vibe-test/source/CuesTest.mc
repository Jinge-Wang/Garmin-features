import Toybox.Lang;
import Toybox.Test;

// Unit tests for the facts in the brief. Build with ./build.sh test; run in
// the simulator's test runner.

(:test)
function cueOrderIsFixed(logger as Logger) as Boolean {
    var expected = "LRRLLRLRRLLR";
    for (var i = 0; i < expected.length(); i++) {
        if (!Cues.letter(i).equals(expected.substring(i, i + 1))) {
            logger.debug("wrong letter at " + i);
            return false;
        }
    }
    return true;
}

(:test)
function patternsMatchTheBrief(logger as Logger) as Boolean {
    var on = 100;
    var want = {
        "A-L" => [[on, 800]],
        "A-R" => [[on, 200], [0, 150], [on, 200], [0, 150], [on, 200]],
        "B-L" => [[on, 400], [0, 200], [on, 400]],
        "B-R" => [[on, 120], [0, 120], [on, 120], [0, 120], [on, 120], [0, 120], [on, 120]]
    };
    for (var set = 0; set < 2; set++) {
        var sides = ["L", "R"];
        for (var k = 0; k < 2; k++) {
            var key = Cues.setName(set) + "-" + sides[k];
            var got = Cues.spec(set, sides[k]);
            var exp = want[key] as Array;
            if (got.size() != exp.size() || got.size() > 8) {
                logger.debug(key + ": wrong count " + got.size());
                return false;
            }
            for (var i = 0; i < got.size(); i++) {
                var g = got[i] as Array<Number>;
                var e = exp[i] as Array<Number>;
                if (g[0] != e[0] || g[1] != e[1]) {
                    logger.debug(key + ": wrong profile " + i);
                    return false;
                }
            }
            if (Cues.profiles(set, sides[k]).size() != got.size()) {
                logger.debug(key + ": profile list differs from spec");
                return false;
            }
        }
    }
    return true;
}
