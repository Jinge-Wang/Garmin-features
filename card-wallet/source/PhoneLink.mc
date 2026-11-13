import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Ignores the outcome of a transmit: the phone's own timeout covers a lost answer.
class AnswerListener extends Communications.ConnectionListener {

    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() as Void {
    }

    function onError() as Void {
    }
}

// The phone link: receives a card from the phone app, stores and shows it, and
// answers with { id, ok, why }. Created only for the full view, never for the
// glance. It makes no web request.
class PhoneLink {

    private var _view as CardView;
    private var _store as CardStore;

    function initialize(view as CardView, store as CardStore) {
        _view = view;
        _store = store;
        // Messages that arrived while the widget was closed are delivered
        // right away, once each.
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onMessage));
        }
    }

    function onMessage(msg as Communications.PhoneAppMessage) as Void {
        handle(msg.data);
    }

    // Checks and stores what the phone sent, shows the stored card (or says
    // why it was refused), sends the answer and returns it. The unit tests
    // call this, since they have no phone.
    function handle(data as Object?) as Dictionary {
        var result = CardInbox.accept(data, System.getDeviceSettings().screenWidth, _store);
        var answer = result["answer"] as Dictionary;
        if ((answer["ok"] as Boolean)) {
            _view.showIndex(result["index"] as Number);
        } else {
            var why = answer["why"] as String;
            _view.setNote(why.equals("full") ? "Storage full" : "Card refused: " + why);
        }
        try {
            Communications.transmit(answer as Communications.TransmitType, {}, new AnswerListener());
        } catch (e) {
            // The phone sees no answer and reports a timeout.
        }
        return answer;
    }
}
