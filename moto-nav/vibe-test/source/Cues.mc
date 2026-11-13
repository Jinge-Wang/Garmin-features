import Toybox.Attention;
import Toybox.Lang;

// The fixed facts of the test: the order of the cues, the intervals and the
// vibration patterns. Pure data and small functions, so the unit test can
// check them without a screen.
class Cues {

    // Cue order, repeated: left, right, right, left, left, right.
    static const ORDER = "LRRLLR";

    // Seconds between cues, chosen on the setup screen.
    static const INTERVALS = [20, 30, 45, 60];

    // Duty cycle of a pulse. A gap is duty cycle 0.
    static const ON = 100;

    // The letter of cue number n (0 is the first cue).
    static function letter(n as Number) as String {
        var i = n % ORDER.length();
        return ORDER.substring(i, i + 1) as String;
    }

    // "A" or "B".
    static function setName(set as Number) as String {
        return set == 0 ? "A" : "B";
    }

    // The pattern as a list of [duty cycle, milliseconds] pairs.
    //   Set A  L: one 800 ms pulse.        R: three 200 ms pulses, 150 ms gaps.
    //   Set B  L: two 400 ms pulses, 200 ms gap.   R: four 120 ms pulses, 120 ms gaps.
    static function spec(set as Number, side as String) as Array {
        if (set == 0) {
            if (side.equals("L")) {
                return [[ON, 800]];
            }
            return [[ON, 200], [0, 150], [ON, 200], [0, 150], [ON, 200]];
        }
        if (side.equals("L")) {
            return [[ON, 400], [0, 200], [ON, 400]];
        }
        return [[ON, 120], [0, 120], [ON, 120], [0, 120], [ON, 120], [0, 120], [ON, 120]];
    }

    // The same pattern as the list the vibration motor takes (at most 8).
    static function profiles(set as Number, side as String) as Array<Attention.VibeProfile> {
        var s = spec(set, side);
        var out = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < s.size(); i++) {
            var p = s[i] as Array<Number>;
            out.add(new Attention.VibeProfile(p[0], p[1]));
        }
        return out;
    }

    // Play the pattern. The watch may have no motor; then nothing happens.
    static function play(set as Number, side as String) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate(profiles(set, side));
        }
    }
}
