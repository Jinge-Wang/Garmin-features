import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Unit tests for CardInbox, the check and the store step of the phone link.
// Like Tests.mc they are not in the app, and they empty the simulator's
// storage for this app. All values here are made up.

const WIDTH = 280;

// A square of modules (0 or 1) with the three position squares set, and one
// data module so the grid is not all finders.
function bitsOf(n as Number) as Array<Array<Number> > {
    var bits = new Array<Array<Number> >[n];
    for (var r = 0; r < n; r++) {
        var row = new Array<Number>[n];
        for (var c = 0; c < n; c++) {
            row[c] = 0;
        }
        bits[r] = row;
    }
    putFinder(bits, 0, 0);
    putFinder(bits, 0, n - 7);
    putFinder(bits, n - 7, 0);
    bits[10][10] = 1;
    return bits;
}

function putFinder(bits as Array<Array<Number> >, row as Number, column as Number) as Void {
    for (var r = 0; r < 7; r++) {
        for (var c = 0; c < 7; c++) {
            var ring = r - 3 > 3 - r ? r - 3 : 3 - r;
            var rc = c - 3 > 3 - c ? c - 3 : 3 - c;
            ring = ring > rc ? ring : rc;
            bits[row + r][column + c] = ring == 2 ? 0 : 1;
        }
    }
}

// The rows as lower-case hex, the leftmost module in the top bit.
function hexOf(bits as Array<Array<Number> >) as Array<String> {
    var digits = "0123456789abcdef";
    var n = bits.size();
    var rows = new Array<String>[n];
    for (var r = 0; r < n; r++) {
        var text = "";
        for (var d = 0; d < (n + 3) / 4; d++) {
            var v = 0;
            for (var k = 0; k < 4; k++) {
                var c = d * 4 + k;
                v = v * 2 + (c < n ? bits[r][c] : 0);
            }
            text += digits.substring(v, v + 1) as String;
        }
        rows[r] = text;
    }
    return rows;
}

function qrMsg(name as String, g as Array<String>, n as Number) as Dictionary {
    return {"v" => 1, "id" => 4711, "name" => name, "kind" => "qr", "n" => n, "g" => g} as Dictionary;
}

function barMsg(name as String, t as String) as Dictionary {
    return {"v" => 1, "id" => 4711, "name" => name, "kind" => "bar", "t" => t} as Dictionary;
}

function validQr() as Dictionary {
    return qrMsg("Gym", hexOf(bitsOf(21)), 21);
}

function with(msg as Dictionary, key as String, value as Object?) as Dictionary {
    var copy = {} as Dictionary;
    var keys = msg.keys();
    for (var i = 0; i < keys.size(); i++) {
        copy[keys[i]] = msg[keys[i]];
    }
    copy[key] = value;
    return copy;
}

function without(msg as Dictionary, key as String) as Dictionary {
    var copy = {} as Dictionary;
    var keys = msg.keys();
    for (var i = 0; i < keys.size(); i++) {
        if (!(keys[i] as String).equals(key)) {
            copy[keys[i]] = msg[keys[i]];
        }
    }
    return copy;
}

function whyOf(msg as Object?) as String {
    return CardInbox.check(msg, WIDTH)["why"] as String;
}

function repeat(ch as String, times as Number) as String {
    var text = "";
    for (var i = 0; i < times; i++) {
        text += ch;
    }
    return text;
}

(:test)
function inboxValidQr(logger as Test.Logger) as Boolean {
    var msg = validQr();
    var result = CardInbox.check(msg, WIDTH);
    Test.assert(sameText(result["why"] as String, ""));
    Test.assertEqual(result["id"] as Number, 4711);
    var rec = result["rec"] as Dictionary;
    Test.assertEqual(rec.size(), 4);
    Test.assert(sameText(rec["name"] as String, "Gym"));
    Test.assert(sameText(rec["kind"] as String, "qr"));
    Test.assertEqual(rec["n"] as Number, 21);
    Test.assert(sameList(rec["g"] as Array, msg["g"] as Array));
    // A 177-module code is the largest.
    Test.assert(sameText(whyOf(qrMsg("Big", hexOf(bitsOf(177)), 177)), ""));
    return true;
}

(:test)
function inboxValidBar(logger as Test.Logger) as Boolean {
    var result = CardInbox.check(barMsg("Shop", "123456"), WIDTH);
    Test.assert(sameText(result["why"] as String, ""));
    var rec = result["rec"] as Dictionary;
    Test.assertEqual(rec.size(), 4);
    Test.assert(sameText(rec["name"] as String, "Shop"));
    Test.assert(sameText(rec["kind"] as String, "bar"));
    Test.assert(sameText(rec["t"] as String, "123456"));
    Test.assert(sameText(rec["b"] as String, Code128.encode("123456")));
    // 24-character name and 80 characters of content are the limits.
    Test.assert(sameText(whyOf(barMsg(repeat("n", 24), "1")), ""));
    // 40 digits are 255 modules, still 1 px each; 42 digits are 266 modules, too wide.
    Test.assert(sameText(whyOf(barMsg("Shop", repeat("7", 40))), ""));
    Test.assert(sameText(whyOf(barMsg("Shop", repeat("7", 42))), "long"));
    return true;
}

(:test)
function inboxFormat(logger as Test.Logger) as Boolean {
    Test.assert(sameText(whyOf("text"), "format"));
    Test.assert(sameText(whyOf(null), "format"));
    Test.assert(sameText(whyOf([1, 2]), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "v", 2)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "v", 1.0f)), "format"));
    Test.assert(sameText(whyOf(without(validQr(), "name")), "format"));
    Test.assert(sameText(whyOf(without(validQr(), "g")), "format"));
    Test.assert(sameText(whyOf(without(barMsg("A", "1"), "t")), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "extra", 1)), "format"));
    Test.assert(sameText(whyOf(with(barMsg("A", "1"), "n", 21)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "id", 5000000000l)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "id", 0)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "id", 1000000001)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "id", "7")), "format"));
    Test.assert(sameText(whyOf(without(validQr(), "id")), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "n", 21.0f)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "n", 21l)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "name", 5)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "g", "abc")), "format"));
    Test.assert(sameText(whyOf(with(barMsg("A", "1"), "t", 12)), "format"));
    Test.assert(sameText(whyOf(with(validQr(), "g", [1, 2, 3])), "format"));
    // The answer echoes a usable id and gives 0 otherwise.
    Test.assertEqual(CardInbox.check(with(validQr(), "v", 2), WIDTH)["id"] as Number, 4711);
    Test.assertEqual(CardInbox.check(with(validQr(), "id", 0), WIDTH)["id"] as Number, 0);
    Test.assertEqual(CardInbox.check("text", WIDTH)["id"] as Number, 0);
    var refused = CardInbox.check(with(validQr(), "v", 2), WIDTH);
    var none = refused["rec"] as Dictionary?;
    Test.assert(none == null);
    return true;
}

(:test)
function inboxName(logger as Test.Logger) as Boolean {
    Test.assert(sameText(whyOf(barMsg("", "1")), "name"));
    Test.assert(sameText(whyOf(barMsg(repeat("n", 25), "1")), "name"));
    Test.assert(sameText(whyOf(barMsg(" Gym", "1")), "name"));
    Test.assert(sameText(whyOf(barMsg("Gym ", "1")), "name"));
    Test.assert(sameText(whyOf(barMsg("Gy\u0001m", "1")), "name"));
    Test.assert(sameText(whyOf(barMsg("Gy\u007fm", "1")), "name"));
    Test.assert(sameText(whyOf(barMsg("Gym club", "1")), ""));
    return true;
}

(:test)
function inboxKind(logger as Test.Logger) as Boolean {
    Test.assert(sameText(whyOf(with(validQr(), "kind", "aztec")), "kind"));
    Test.assert(sameText(whyOf(with(validQr(), "kind", "QR")), "kind"));
    // The name rule is checked before the kind.
    Test.assert(sameText(whyOf(with(with(validQr(), "kind", "aztec"), "name", "")), "name"));
    return true;
}

(:test)
function inboxSize(logger as Test.Logger) as Boolean {
    var g = hexOf(bitsOf(21));
    Test.assert(sameText(whyOf(with(validQr(), "n", 20)), "size"));
    Test.assert(sameText(whyOf(with(validQr(), "n", 22)), "size"));
    Test.assert(sameText(whyOf(with(validQr(), "n", 17)), "size"));
    Test.assert(sameText(whyOf(qrMsg("Big", hexOf(bitsOf(181)), 181)), "size"));
    // One row too few, and one too many.
    Test.assert(sameText(whyOf(with(validQr(), "g", g.slice(0, 20))), "size"));
    Test.assert(sameText(whyOf(with(validQr(), "g", g.slice(0, 21).add("000000"))), "size"));
    // A row one digit short, and one digit long.
    var short = g.slice(0, 21);
    short[5] = "00000";
    Test.assert(sameText(whyOf(with(validQr(), "g", short)), "size"));
    var long = g.slice(0, 21);
    long[5] = "0000000";
    Test.assert(sameText(whyOf(with(validQr(), "g", long)), "size"));
    return true;
}

(:test)
function inboxChars(logger as Test.Logger) as Boolean {
    var g = hexOf(bitsOf(21));
    var upper = g.slice(0, 21);
    upper[10] = "000A00";
    Test.assert(sameText(whyOf(with(validQr(), "g", upper)), "chars"));
    var other = g.slice(0, 21);
    other[10] = "00g000";
    Test.assert(sameText(whyOf(with(validQr(), "g", other)), "chars"));
    var space = g.slice(0, 21);
    space[10] = "00 000";
    Test.assert(sameText(whyOf(with(validQr(), "g", space)), "chars"));
    // n = 21 has 3 padding bits in the sixth digit: "8" is the module 20, "9" sets a padding bit.
    var pad = g.slice(0, 21);
    pad[10] = "000009";
    Test.assert(sameText(whyOf(with(validQr(), "g", pad)), "chars"));
    // A check of size comes before a check of characters.
    var both = g.slice(0, 21);
    both[10] = "000A0";
    Test.assert(sameText(whyOf(with(validQr(), "g", both)), "size"));
    // n = 25 has no padding bits, so a low bit there is data.
    Test.assert(sameText(whyOf(qrMsg("N25", hexOf(bitsOf(25)), 25)), ""));
    return true;
}

(:test)
function inboxShape(logger as Test.Logger) as Boolean {
    var noTopLeft = bitsOf(21);
    noTopLeft[0][0] = 0;
    Test.assert(sameText(whyOf(qrMsg("A", hexOf(noTopLeft), 21)), "shape"));
    var noTopRight = bitsOf(21);
    noTopRight[3][17] = 0;
    Test.assert(sameText(whyOf(qrMsg("A", hexOf(noTopRight), 21)), "shape"));
    var noBottomLeft = bitsOf(21);
    noBottomLeft[19][5] = 1;
    Test.assert(sameText(whyOf(qrMsg("A", hexOf(noBottomLeft), 21)), "shape"));
    var four = bitsOf(21);
    putFinder(four, 14, 14);
    Test.assert(sameText(whyOf(qrMsg("A", hexOf(four), 21)), "shape"));
    var empty = new Array<Array<Number> >[21];
    for (var r = 0; r < 21; r++) {
        empty[r] = new Array<Number>[21];
        for (var c = 0; c < 21; c++) {
            empty[r][c] = 0;
        }
    }
    Test.assert(sameText(whyOf(qrMsg("A", hexOf(empty), 21)), "shape"));
    return true;
}

(:test)
function inboxContent(logger as Test.Logger) as Boolean {
    Test.assert(sameText(whyOf(barMsg("A", "")), "content"));
    Test.assert(sameText(whyOf(barMsg("A", repeat("1", 81))), "content"));
    Test.assert(sameText(whyOf(barMsg("A", "café")), "content"));
    Test.assert(sameText(whyOf(barMsg("A", "a\u007fb")), "content"));
    Test.assert(sameText(whyOf(barMsg("A", "a\u0009b")), "content"));
    Test.assert(sameText(whyOf(barMsg("A", "a b~")), ""));
    return true;
}

(:test)
function inboxLong(logger as Test.Logger) as Boolean {
    // 80 characters in code set B: far wider than the 262 px the bars may use.
    var t = repeat("A", 80);
    Test.assert(Code128.encode(t) != null);
    Test.assert(sameText(whyOf(barMsg("A", t)), "long"));
    // The same text on a wider screen would fit at 1 px.
    Test.assert(sameText(CardInbox.check(barMsg("A", t), 1200)["why"] as String, ""));
    return true;
}

(:test)
function inboxAcceptStoresAndAnswers(logger as Test.Logger) as Boolean {
    Storage.clearValues();
    var store = new CardStore();
    var done = CardInbox.accept(validQr(), WIDTH, store);
    var answer = done["answer"] as Dictionary;
    Test.assertEqual(answer.size(), 3);
    Test.assertEqual(answer["id"] as Number, 4711);
    Test.assert(answer["ok"] as Boolean);
    Test.assert(sameText(answer["why"] as String, ""));
    Test.assertEqual(done["index"] as Number, 0);
    Test.assertEqual(store.count(), 1);
    var rec = store.record(0) as Dictionary;
    Test.assertEqual(rec.size(), 4);
    Test.assert(rec.hasKey("name") && rec.hasKey("kind") && rec.hasKey("n") && rec.hasKey("g"));

    var bar = CardInbox.accept(barMsg("Shop", "123456"), WIDTH, store);
    Test.assertEqual(bar["index"] as Number, 1);
    var brec = store.record(1) as Dictionary;
    Test.assertEqual(brec.size(), 4);
    Test.assert(brec.hasKey("name") && brec.hasKey("kind") && brec.hasKey("t") && brec.hasKey("b"));

    // A refused message stores nothing, and the answer has no name or content.
    var bad = CardInbox.accept(barMsg("Shop2", ""), WIDTH, store);
    var banswer = bad["answer"] as Dictionary;
    Test.assertEqual(banswer.size(), 3);
    Test.assert(!(banswer["ok"] as Boolean));
    Test.assert(sameText(banswer["why"] as String, "content"));
    Test.assertEqual(bad["index"] as Number, -1);
    Test.assertEqual(store.count(), 2);
    Storage.clearValues();
    return true;
}

(:test)
function inboxSameNameReplacesInPlace(logger as Test.Logger) as Boolean {
    Storage.clearValues();
    var store = new CardStore();
    CardInbox.accept(barMsg("First", "111111"), WIDTH, store);
    CardInbox.accept(barMsg("Second", "222222"), WIDTH, store);
    var ids = (Storage.getValue("ids") as Array).slice(0, 2);

    var again = CardInbox.accept(with(barMsg("First", "999999"), "id", 5), WIDTH, store);
    Test.assert((again["answer"] as Dictionary)["ok"] as Boolean);
    Test.assertEqual((again["answer"] as Dictionary)["id"] as Number, 5);
    Test.assertEqual(again["index"] as Number, 0);
    Test.assertEqual(store.count(), 2);
    Test.assert(sameList(Storage.getValue("ids"), ids));
    Test.assert(sameText((store.record(0) as Dictionary)["t"] as String, "999999"));
    Test.assert(sameText((store.record(1) as Dictionary)["t"] as String, "222222"));
    Test.assert(sameList(Storage.getValue("names"), ["First", "Second"]));

    // A card of another kind under the same name replaces it too.
    var qr = CardInbox.accept(qrMsg("First", hexOf(bitsOf(21)), 21), WIDTH, store);
    Test.assertEqual(qr["index"] as Number, 0);
    Test.assertEqual(store.count(), 2);
    Test.assert(sameText((store.record(0) as Dictionary)["kind"] as String, "qr"));
    Test.assert(!(store.record(0) as Dictionary).hasKey("t"));

    // A new name is appended.
    var added = CardInbox.accept(barMsg("Third", "333333"), WIDTH, store);
    Test.assertEqual(added["index"] as Number, 2);
    Test.assertEqual(store.count(), 3);
    Test.assert(sameList(Storage.getValue("names"), ["First", "Second", "Third"]));
    Storage.clearValues();
    return true;
}

// The link itself, without a phone: a message handed to it is stored, the card
// view moves to the stored card, and a refused message changes nothing.
(:test)
function phoneLinkStoresAndShows(logger as Test.Logger) as Boolean {
    Storage.clearValues();
    var store = new CardStore();
    var view = new CardView(store);
    var link = new PhoneLink(view, store);

    var first = link.handle(validQr());
    Test.assert(first["ok"] as Boolean);
    Test.assertEqual(first["id"] as Number, 4711);
    Test.assertEqual(store.count(), 1);
    Test.assertEqual(view.index(), 0);

    var second = link.handle(barMsg("Shop", "123456"));
    Test.assert(second["ok"] as Boolean);
    Test.assertEqual(store.count(), 2);
    Test.assertEqual(view.index(), 1);

    // Sending "Gym" again shows that card, in its old place.
    link.handle(validQr());
    Test.assertEqual(store.count(), 2);
    Test.assertEqual(view.index(), 0);

    var refused = link.handle(barMsg("Other", ""));
    Test.assert(!(refused["ok"] as Boolean));
    Test.assert(sameText(refused["why"] as String, "content"));
    Test.assertEqual(refused.size(), 3);
    Test.assertEqual(store.count(), 2);
    Test.assertEqual(view.index(), 0);

    Test.assert(!(link.handle("not a card")["ok"] as Boolean));
    Storage.clearValues();
    return true;
}

// Two grids exactly as tools/cardtool.swift writes them, for dummy codes (the
// first two pictures of android/fixtures, where the phone app's tests read the
// same grids): a real symbol passes the check and is stored unchanged.
(:test)
function inboxAcceptsToolGrids(logger as Test.Logger) as Boolean {
    var short = [
        "fe2bf8", "82aa08", "bab2e8", "ba0ae8",
        "bafae8", "82e208", "feabf8", "008000",
        "d33bb0", "8d5118", "62f648", "b96f60",
        "f23290", "00c7a0", "fe9ad8", "826320",
        "ba0e88", "ba87f8", "ba5648", "8298a8",
        "fe8400"
    ] as Array<String>;
    var medium = [
        "fe6073f8", "82619a08", "bab9aae8", "bad012e8",
        "bafdf2e8", "82cf9208", "feaaabf8", "0095e800",
        "be2a73e0", "74a1f478", "6aa85ce8", "a9022e78",
        "5f1014e8", "d5ef67b8", "0ae6c2a8", "30852c88",
        "6bdb4680", "d42974b8", "bf098ac0", "90239ee8",
        "86593fc8", "00b768f0", "fe1f1ac8", "828408d0",
        "babb7f98", "bae576f0", "ba9f5eb0", "821daad8",
        "fe9b2890"
    ] as Array<String>;
    Test.assert(sameText(whyOf(qrMsg("Short", short, 21)), ""));
    Test.assert(sameText(whyOf(qrMsg("Medium", medium, 29)), ""));

    Storage.clearValues();
    var store = new CardStore();
    var done = CardInbox.accept(qrMsg("Medium", medium, 29), WIDTH, store);
    Test.assert((done["answer"] as Dictionary)["ok"] as Boolean);
    var rec = store.record(0) as Dictionary;
    Test.assertEqual(rec["n"] as Number, 29);
    Test.assert(sameList(rec["g"] as Array, medium));
    // The view's decoder gives the same number of rows.
    Test.assertEqual(CardCodec.qrRows(rec["g"] as Array, 29).size(), 29);
    Storage.clearValues();
    return true;
}
