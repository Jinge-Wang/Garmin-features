import Toybox.Lang;
import Toybox.WatchUi;

// UP and DOWN change the card; START turns the light back on; the menu (a
// long press of UP on this watch) opens the list of changes.
class CardDelegate extends WatchUi.BehaviorDelegate {

    private var _view as CardView;
    private var _store as CardStore;

    function initialize(view as CardView, store as CardStore) {
        BehaviorDelegate.initialize();
        _view = view;
        _store = store;
    }

    function onNextPage() as Boolean {
        _view.step(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.step(-1);
        return true;
    }

    function onSelect() as Boolean {
        _view.lightOn();
        return true;
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => "Cards"});
        menu.addItem(new WatchUi.MenuItem("Add bar code", null, :add, {}));
        if (_store.count() > 0) {
            menu.addItem(new WatchUi.MenuItem("Rename", null, :rename, {}));
            menu.addItem(new WatchUi.MenuItem("Delete", null, :delete, {}));
        }
        WatchUi.pushView(menu, new MenuDelegate(_view, _store), WatchUi.SLIDE_UP);
        return true;
    }
}
