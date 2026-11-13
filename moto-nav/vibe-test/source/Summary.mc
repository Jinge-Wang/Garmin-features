import Toybox.Application.Storage;
import Toybox.Lang;

// The last run's summary, kept in the app's storage. A summary is a
// dictionary: dur (seconds), n (cues fired), iv (interval, seconds),
// set ("A" or "B") and seq (the letters fired).
class Summary {

    static function save(result as Dictionary) as Void {
        Storage.setValue("last", result as Dictionary<Storage.KeyType, Storage.ValueType>);
    }

    // The stored summary, or null when no run has been made yet.
    static function load() as Dictionary? {
        var v = Storage.getValue("last");
        return v instanceof Dictionary ? v : null;
    }
}
