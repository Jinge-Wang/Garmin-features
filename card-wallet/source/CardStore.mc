import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

// The cards on the watch, kept in Application.Storage (see README, "Storage").
//   "ids"   card order, as Numbers      "next"  the next free id
//   "names" the names, in the same order (the glance reads only this)
//   "seed"  stamp of the built-in list that was imported
//   "c<id>" one record per card
class CardStore {

    function initialize() {
    }

    // Storage.setValue with the argument typed as a plain Object, which the
    // type checker accepts for the Arrays and Dictionaries kept here.
    private function put(key as String, value as Object) as Void {
        Storage.setValue(key, value as Storage.ValueType);
    }

    function ids() as Array<Number> {
        var v = Storage.getValue("ids");
        if (v == null) {
            return [] as Array<Number>;
        }
        return v as Array<Number>;
    }

    function names() as Array<String> {
        var v = Storage.getValue("names");
        if (v == null) {
            return [] as Array<String>;
        }
        return v as Array<String>;
    }

    function count() as Number {
        return ids().size();
    }

    function name(index as Number) as String {
        var list = names();
        return index >= 0 && index < list.size() ? list[index] : "";
    }

    // The stored record of the card at this position, or null.
    function record(index as Number) as Dictionary? {
        var list = ids();
        if (index < 0 || index >= list.size()) {
            return null;
        }
        var v = Storage.getValue("c" + list[index].toString());
        return v == null ? null : v as Dictionary;
    }

    // The position of the card with this name, or -1.
    function indexOfName(text as String) as Number {
        var list = names();
        for (var i = 0; i < list.size(); i++) {
            if (list[i].equals(text)) {
                return i;
            }
        }
        return -1;
    }

    // Appends a card; returns its position, or -1 when the storage is full.
    function add(rec as Dictionary) as Number {
        var list = ids();
        var nm = names();
        var next = Storage.getValue("next");
        var id = next == null ? 1 : next as Number;
        var ok = true;
        try {
            put("c" + id.toString(), rec);
            list.add(id);
            nm.add(rec["name"] as String);
            put("ids", list);
            put("names", nm);
            put("next", id + 1);
        } catch (e) {
            ok = false;
        }
        if (!ok) {
            try {
                Storage.deleteValue("c" + id.toString());
            } catch (e2) {
            }
            return -1;
        }
        return list.size() - 1;
    }

    // Replaces the record at a position (same id, same place in the order).
    function replace(index as Number, rec as Dictionary) as Boolean {
        var list = ids();
        if (index < 0 || index >= list.size()) {
            return false;
        }
        var nm = names();
        try {
            put("c" + list[index].toString(), rec);
            nm[index] = rec["name"] as String;
            put("names", nm);
        } catch (e) {
            return false;
        }
        return true;
    }

    function rename(index as Number, text as String) as Boolean {
        var rec = record(index);
        if (rec == null) {
            return false;
        }
        rec["name"] = text;
        return replace(index, rec);
    }

    // Removes the card and its storage key.
    function remove(index as Number) as Void {
        var list = ids();
        if (index < 0 || index >= list.size()) {
            return;
        }
        var nm = names();
        var keptIds = [] as Array<Number>;
        var keptNames = [] as Array<String>;
        for (var i = 0; i < list.size(); i++) {
            if (i != index) {
                keptIds.add(list[i]);
                keptNames.add(nm[i]);
            }
        }
        try {
            Storage.deleteValue("c" + list[index].toString());
            put("ids", keptIds);
            put("names", keptNames);
        } catch (e) {
        }
    }

    // Imports the built-in list (the resource written by tools/cardtool.swift)
    // when its stamp differs from the stamp stored at the last import: a stored
    // card of the same name is replaced, otherwise the card is appended. A
    // built-in card that was deleted therefore stays deleted until the list
    // changes. Called only from the full view, never from the glance.
    function seed() as Void {
        var data = WatchUi.loadResource(Rez.JsonData.cards) as Dictionary;
        var stamp = data["stamp"] as String;
        var done = Storage.getValue("seed");
        if (done != null && stamp.equals(done as String)) {
            return;
        }
        var cards = data["cards"] as Array;
        for (var i = 0; i < cards.size(); i++) {
            var card = cards[i] as Dictionary;
            var rec = null;
            if ("bar".equals(card["kind"] as String?)) {
                var t = card["t"] as String;
                var b = Code128.encode(t);
                if (b != null) {
                    rec = {"name" => card["name"], "kind" => "bar", "t" => t, "b" => b};
                }
            } else {
                rec = {"name" => card["name"], "kind" => "qr", "n" => card["n"], "g" => card["g"]};
            }
            if (rec == null) {
                continue;
            }
            var at = indexOfName(card["name"] as String);
            var ok = at >= 0 ? replace(at, rec as Dictionary) : add(rec as Dictionary) >= 0;
            if (!ok) {
                return;     // storage full: try again at the next start
            }
        }
        try {
            put("seed", stamp);
        } catch (e) {
        }
    }
}
