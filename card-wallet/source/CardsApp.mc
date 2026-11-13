import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Cards: bar codes and QR codes of membership cards, kept in the watch's
// storage. The built-in list is imported once per build (see CardStore.seed).
// The only permission is the phone link (a card sent from the phone app); the
// code makes no web request.
(:glance)
class CardsApp extends Application.AppBase {

    // Kept so the registered callback stays alive; made in the full view only.
    private var _link as PhoneLink? = null;

    function initialize() {
        AppBase.initialize();
    }

    function phoneLink() as PhoneLink? {
        return _link;
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    // The full-screen view, opened from the glance with START. The import of
    // the built-in cards happens here, never in the glance.
    (:typecheck(false))
    function getInitialView() {
        var store = new CardStore();
        store.seed();
        var view = new CardView(store);
        _link = new PhoneLink(view, store);
        return [view, new CardDelegate(view, store)];
    }

    // The one-line entry in the widget list.
    function getGlanceView() {
        return [new CardsGlanceView()];
    }
}
