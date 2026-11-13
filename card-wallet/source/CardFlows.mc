import Toybox.Lang;
import Toybox.WatchUi;

// What the menu items do. Each one closes the menu and opens the next view, so
// that when the last view of a flow closes, the card view is on top again.
class MenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as CardView;
    private var _store as CardStore;

    function initialize(view as CardView, store as CardStore) {
        Menu2InputDelegate.initialize();
        _view = view;
        _store = store;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var index = _view.index();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (id == :add) {
            var entry = new DigitView();
            WatchUi.pushView(entry, new DigitDelegate(entry, _view, _store), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :rename) {
            WatchUi.pushView(new WatchUi.TextPicker(_store.name(index)), new RenameDelegate(_view, _store, index),
                WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :delete) {
            WatchUi.pushView(new WatchUi.Confirmation("Delete " + _store.name(index) + "?"),
                new DeleteDelegate(_view, _store, index), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

// Rename: the text entry starts with the current name.
class RenameDelegate extends WatchUi.TextPickerDelegate {

    private var _view as CardView;
    private var _store as CardStore;
    private var _index as Number;

    function initialize(view as CardView, store as CardStore, index as Number) {
        TextPickerDelegate.initialize();
        _view = view;
        _store = store;
        _index = index;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        if (changed && text.length() > 0) {
            if (!_store.rename(_index, text)) {
                _view.setNote("Storage full");
            }
        }
        _view.reload();
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}

// Delete: the system's yes/no dialog.
class DeleteDelegate extends WatchUi.ConfirmationDelegate {

    private var _view as CardView;
    private var _store as CardStore;
    private var _index as Number;

    function initialize(view as CardView, store as CardStore, index as Number) {
        ConfirmationDelegate.initialize();
        _view = view;
        _store = store;
        _index = index;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _store.remove(_index);
            _view.reload();
        }
        return true;
    }
}

// Add bar code, second step: the name. The code is saved when the name is
// entered; backing out of the name entry drops it.
class AddDelegate extends WatchUi.TextPickerDelegate {

    private var _view as CardView;
    private var _store as CardStore;
    private var _digits as String;
    private var _widths as String;

    function initialize(view as CardView, store as CardStore, digits as String, widths as String) {
        TextPickerDelegate.initialize();
        _view = view;
        _store = store;
        _digits = digits;
        _widths = widths;
    }

    function onTextEntered(text as String, changed as Boolean) as Boolean {
        var name = text.length() > 0 ? text : "Card " + (_store.count() + 1).toString();
        var at = _store.add({"name" => name, "kind" => "bar", "t" => _digits, "b" => _widths});
        if (at < 0) {
            _view.setNote("Storage full");
        } else {
            _view.showIndex(at);
        }
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}
