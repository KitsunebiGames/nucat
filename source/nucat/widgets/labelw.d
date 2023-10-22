module nucat.widgets.labelw;
import 
    dplug.core, 
    dplug.client, 
    dplug.gui,
    dplug.canvas,
    dplug.pbrwidgets;

import 
    nucat.widgets;

final
class UILabeled(T) : UIElement if (is(T : UIElement)) {
nothrow:
@nogc:
private:
    T _element;
    UILabel _label;

public:
    this(UIContext context, T child, string label) {
        super(context, 0);

        _element = child;
        _label = mallocNew!UILabel(context, wtUiFont, label);
        _label.setCursorWhenMouseOver(MouseCursor.pointer);
        _label.textColor = RGBA(255, 255, 255, 32);

        addChild(_element);
        addChild(_label);
    }

    ref T getElement() {
        return _element;
    }

    ref UILabel getLabel() {
        return _label;
    }

    override
    void reflow() {
        int x = position.min.x;
        int y = position.min.y;
        int w = position.width;

        _element.position = rectangle(x, y, w, w);
        _label.position = rectangle(x, y+(w-4), w, 24);
    }
}
