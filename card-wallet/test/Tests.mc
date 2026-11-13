import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Unit tests. They are not in the app: test.jungle adds this folder, and the
// build needs --unit-test (see README, "Checks").
// They empty the simulator's storage for this app.

// Strings and Arrays are compared by content here, not with ==.
function sameText(a as String?, b as String?) as Boolean {
    return a == null ? b == null : a.equals(b);
}

function sameList(first as Object?, second as Object) as Boolean {
    if (first == null) {
        return false;
    }
    var a = first as Array;
    var b = second as Array;
    if (a.size() != b.size()) {
        return false;
    }
    for (var i = 0; i < b.size(); i++) {
        if (!(a[i] as Object).equals(b[i] as Object)) {
            return false;
        }
    }
    return true;
}

function stored(key as String) as Boolean {
    return Storage.getValue(key) != null;
}

// The three vectors were made by tools/code128_check.swift, whose encoder was
// checked by drawing and reading back 3,000 random inputs.
(:test)
function encodeSetC(logger as Test.Logger) as Boolean {
    Test.assert(sameText(Code128.encode("123456"), "2112321122321311233311211321312331112"));
    return true;
}

(:test)
function encodeOddDigits(logger as Test.Logger) as Boolean {
    Test.assert(sameText(Code128.encode("12345"), "2112141232211131413121311131232131312331112"));
    return true;
}

(:test)
function encodeSetB(logger as Test.Logger) as Boolean {
    Test.assert(sameText(Code128.encode("Hi-5"), "2112142311131421121221322132122221222331112"));
    return true;
}

(:test)
function encodeRefuses(logger as Test.Logger) as Boolean {
    Test.assert(Code128.encode("") == null);
    Test.assert(Code128.encode("caf\u00e9") == null);
    return true;
}

(:test)
function moduleWidthShrinksWithLength(logger as Test.Logger) as Boolean {
    // 6 digits: 11 * 5 + 13 = 68 modules; a 280 px screen has a 270 px chord.
    Test.assertEqual(Code128.moduleCount(Code128.encode("123456") as String), 68);
    Test.assertEqual(Code128.modulePx(68, 280), 3);
    Test.assertEqual(Code128.modulePx(500, 280), 0);
    return true;
}

(:test)
function hexRowToRuns(logger as Test.Logger) as Boolean {
    // "a8" over 6 modules: 1 0 1 0 1 0 (the last two bits are padding)
    Test.assert(sameList(CardCodec.rowRuns("a8", 6), [0, 1, 2, 1, 4, 1]));
    // "ff8" over 9 modules: nine dark modules, the last three bits are padding
    Test.assert(sameList(CardCodec.rowRuns("ff8", 9), [0, 9]));
    Test.assert(sameList(CardCodec.rowRuns("000", 9), [] as Array<Number>));
    // A run that ends at the last module, and one that starts after a gap
    Test.assert(sameList(CardCodec.rowRuns("1c", 8), [3, 3]));
    Test.assert(sameList(CardCodec.rowRuns("01", 8), [7, 1]));
    return true;
}

(:test)
function storeAddRenameDelete(logger as Test.Logger) as Boolean {
    Storage.clearValues();
    var store = new CardStore();
    Test.assertEqual(store.count(), 0);

    var first = store.add({"name" => "One", "kind" => "bar", "t" => "123456", "b" => Code128.encode("123456")});
    var second = store.add({"name" => "Two", "kind" => "qr", "n" => 9, "g" => ["ff8", "000", "000", "000", "000", "000", "000", "000", "000"]});
    Test.assertEqual(first, 0);
    Test.assertEqual(second, 1);
    Test.assertEqual(store.count(), 2);
    Test.assert(sameList(Storage.getValue("names"), ["One", "Two"]));

    Test.assert(store.rename(0, "Uno"));
    Test.assert(sameText(store.name(0), "Uno"));
    Test.assert(sameList(Storage.getValue("names"), ["Uno", "Two"]));
    Test.assert(sameText((store.record(0) as Dictionary)["name"] as String, "Uno"));

    var firstId = (Storage.getValue("ids") as Array)[0] as Number;
    var keyOfFirst = "c" + firstId.toString();
    Test.assert(stored(keyOfFirst));
    store.remove(0);
    Test.assertEqual(store.count(), 1);
    Test.assert(sameList(Storage.getValue("names"), ["Two"]));
    Test.assert(!stored(keyOfFirst));
    Test.assertEqual(store.indexOfName("Two"), 0);

    // A new card gets a new id, not the id of the deleted one.
    store.add({"name" => "Three", "kind" => "bar", "t" => "1", "b" => Code128.encode("1")});
    Test.assert(!stored(keyOfFirst));
    Test.assert(sameList(Storage.getValue("ids"), [2, 3]));
    Storage.clearValues();
    return true;
}

(:test)
function seedImportsOnceAndKeepsDeletions(logger as Test.Logger) as Boolean {
    Storage.clearValues();
    var store = new CardStore();
    store.seed();
    var built = store.count();
    Test.assert(built >= 1);
    store.seed();
    Test.assertEqual(store.count(), built);
    store.remove(0);
    store.seed();
    Test.assertEqual(store.count(), built - 1);
    Storage.clearValues();
    return true;
}
