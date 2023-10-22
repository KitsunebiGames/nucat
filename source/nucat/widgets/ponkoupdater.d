/**
    Ponkovision updater
*/
module nucat.widgets.ponkoupdater;

import std.math;
import dplug.gui.element;
import dplug.core.math;
import dplug.graphics;
import dplug.graphics.resizer;
import std.algorithm.comparison;
import nucat.synth;

class UIPonkoUpdater(T) : UIElement {
nothrow:
@nogc:
private:
    T ponkovision;
    NuCatSynth synth;

public:
    
    /// Note: once called, the logo now own the diffuse image, and will destroy it.
    this(UIContext context, T ponkovision, NuCatSynth synth) {
        super(context, flagAnimated);
        this.ponkovision = ponkovision;
        this.synth = synth;
    }

    ~this() {

    }

    override void reflow() {
        
    }

    override void onAnimate(double dt, double time) nothrow @nogc {
        ponkovision.animScrub = clamp(synth.getPonkoADSR(), 0, 1);
    }
}
