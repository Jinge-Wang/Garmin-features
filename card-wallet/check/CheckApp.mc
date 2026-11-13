import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// A build for looking at the screens without pressing buttons. It is the
// widget's own code, started as a watch app (so it opens on the card view, not
// on the glance), plus a timer that presses the buttons in a fixed order and
// then hands the phone link four messages as the phone app would send them. It
// prints "step N ..." after each press, so a capture of the simulator's window
// can be taken after every step.
//
// Never part of the widget: only check.jungle adds this folder. It starts by
// emptying the storage of the check build (which has its own app id).
class CheckApp extends CardsApp {

    private var _timer as Timer.Timer?;
    private var _step as Number = 0;
    private var _view as CardView?;
    private var _store as CardStore?;
    private var _cards as CardDelegate?;
    private var _phone as PhoneLink?;
    private var _pos as Number = 0;       // where the digit entry's choice stands
    private var _typed as String = "";

    function initialize() {
        CardsApp.initialize();
    }

    (:typecheck(false))
    function getInitialView() {
        Storage.clearValues();
        var store = new CardStore();
        store.seed();
        var view = new CardView(store);
        var delegate = new CardDelegate(view, store);
        _store = store;
        _view = view;
        _cards = delegate;
        _phone = new PhoneLink(view, store);
        _timer = new Timer.Timer();
        _timer.start(method(:onStep), 3000, true);
        System.println("step 0 first card of " + store.count());
        return [view, delegate];
    }

    // The delegate of the view on top, or null.
    (:typecheck(false))
    private function top() {
        var current = WatchUi.getCurrentView();
        return current == null ? null : current[1];
    }

    // Types digits into the digit entry with its own UP/DOWN and START.
    (:typecheck(false))
    private function type(digits as String) as Void {
        var entry = top();
        var chars = digits.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var want = chars[i].toNumber() - 48;
            while (_pos != want) {
                entry.onNextPage();
                _pos = (_pos + 1) % 11;
            }
            entry.onSelect();
            _typed += chars[i].toString();
        }
    }

    // Two grids exactly as tools/cardtool.swift writes them for dummy codes
    // (android/fixtures: "Medium M" reads SAMPLE-CARD-0000 dummy membership
    // 0123456789, "Short L" reads SAMPLE-0001).
    private function mediumGrid() as Array<String> {
        return [
            "fe6073f8", "82619a08", "bab9aae8", "bad012e8",
            "bafdf2e8", "82cf9208", "feaaabf8", "0095e800",
            "be2a73e0", "74a1f478", "6aa85ce8", "a9022e78",
            "5f1014e8", "d5ef67b8", "0ae6c2a8", "30852c88",
            "6bdb4680", "d42974b8", "bf098ac0", "90239ee8",
            "86593fc8", "00b768f0", "fe1f1ac8", "828408d0",
            "babb7f98", "bae576f0", "ba9f5eb0", "821daad8",
            "fe9b2890"
        ] as Array<String>;
    }

    private function shortGrid() as Array<String> {
        return [
            "fe2bf8", "82aa08", "bab2e8", "ba0ae8",
            "bafae8", "82e208", "feabf8", "008000",
            "d33bb0", "8d5118", "62f648", "b96f60",
            "f23290", "00c7a0", "fe9ad8", "826320",
            "ba0e88", "ba87f8", "ba5648", "8298a8",
            "fe8400"
        ] as Array<String>;
    }

    // Hands the phone link a message, as if the phone app had sent it, and
    // says what the link answered and what the card view now shows.
    (:typecheck(false))
    private function phone(msg as Dictionary) as String {
        var answer = _phone.handle(msg);
        var text = answer["ok"] ? "stored" : "refused (" + answer["why"] + ")";
        return text + "; cards " + _store.count() + ", showing " + (_view.index() + 1);
    }

    (:typecheck(false))
    function onStep() as Void {
        _step++;
        var s = _step;
        var what = "";
        if (s == 1) {
            _cards.onNextPage();
            what = "second card";
        } else if (s == 2) {
            _cards.onMenu();
            what = "menu";
        } else if (s == 3) {
            new MenuDelegate(_view, _store).onSelect(new WatchUi.MenuItem("Add bar code", null, :add, {}));
            what = "digit entry, empty; top is " + (top() == null ? "null" : "a delegate");
        } else if (s == 4) {
            type("401234");
            what = "typed 401234";
        } else if (s == 5) {
            top().onBack();
            _typed = _typed.substring(0, _typed.length() - 1);
            what = "BACK deleted one digit";
        } else if (s == 6) {
            type("45678901");
            what = "typed up to " + _typed;
        } else if (s == 7) {
            var entry = top();
            while (_pos != 10) {
                entry.onNextPage();
                _pos = (_pos + 1) % 11;
            }
            what = "OK is shown";
        } else if (s == 8) {
            top().onSelect();
            what = "name entry; top is " + (top() == null ? "null" : "a delegate");
        } else if (s == 9) {
            var d = top();
            if (d == null || !(d instanceof AddDelegate)) {
                d = new AddDelegate(_view, _store, _typed, Code128.encode(_typed));
                what = "(delegate rebuilt) ";
            }
            d.onTextEntered("Gym", true);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            what += "new card saved as Gym; cards " + _store.count();
        } else if (s == 10) {
            _cards.onMenu();
            what = "menu on the new card";
        } else if (s == 11) {
            new MenuDelegate(_view, _store).onSelect(new WatchUi.MenuItem("Rename", null, :rename, {}));
            what = "rename entry";
        } else if (s == 12) {
            var d = top();
            if (d == null || !(d instanceof RenameDelegate)) {
                d = new RenameDelegate(_view, _store, _view.index());
                what = "(delegate rebuilt) ";
            }
            d.onTextEntered("Club", true);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            what += "renamed to " + _store.name(_view.index());
        } else if (s == 13) {
            _cards.onMenu();
            what = "menu again";
        } else if (s == 14) {
            new MenuDelegate(_view, _store).onSelect(new WatchUi.MenuItem("Delete", null, :delete, {}));
            what = "delete question";
        } else if (s == 15) {
            var d = top();
            if (d == null || !(d instanceof DeleteDelegate)) {
                d = new DeleteDelegate(_view, _store, _view.index());
                what = "(delegate rebuilt) ";
            }
            d.onResponse(WatchUi.CONFIRM_YES);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            what += "deleted; cards " + _store.count();
        } else if (s == 16) {
            while (_store.count() > 0) {
                _store.remove(0);
            }
            _view.reload();
            what = "no cards";
        } else if (s == 17) {
            _cards.onMenu();
            what = "menu with no cards";
        } else if (s == 18) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            what = "phone sent a QR code: " + phone({"v" => 1, "id" => 1, "name" => "Phone QR", "kind" => "qr",
                "n" => 29, "g" => mediumGrid()});
        } else if (s == 19) {
            what = "phone sent a bar code: " + phone({"v" => 1, "id" => 2, "name" => "Phone bar", "kind" => "bar",
                "t" => "000012345678"});
        } else if (s == 20) {
            what = "phone sent another code under the first name: " + phone({"v" => 1, "id" => 3, "name" => "Phone QR",
                "kind" => "qr", "n" => 21, "g" => shortGrid()});
        } else if (s == 21) {
            what = "phone sent a bar code that cannot be coded: " + phone({"v" => 1, "id" => 4, "name" => "Other",
                "kind" => "bar", "t" => "caf\u00e9"});
        } else {
            _timer.stop();
            System.println("step " + s + " done");
            return;
        }
        System.println("step " + s + " " + what);
    }
}
