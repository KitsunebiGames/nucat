module nucat.ui;
import 
    dplug.core, 
    dplug.client, 
    dplug.gui,
    dplug.pbrwidgets,
    dplug.canvas;

import 
    nucat.common, 
    nucat.synth,
    nucat.widgets;


alias UIPonkoVision = UIPonko!([
    "tex/ponko/ponko_1.png",
    "tex/ponko/ponko_2.png",
    "tex/ponko/ponko_3.png",
    "tex/ponko/ponko_4.png",
    "tex/ponko/ponko_5.png",
    "tex/ponko/ponko_6.png",
    "tex/ponko/ponko_7.png",
    "tex/ponko/ponko_8.png",
    "tex/ponko/ponko_9.png",
]);

/**
    User interface of synth
*/
final class WavetableSynthInterface : PBRBackgroundGUI!("tex/albedo.png", "tex/emissive.png", "tex/material.png", "tex/depth.png", "tex/skybox.png", "") {
nothrow:
@nogc:
private:
    NuCatSynth _synth;

    Font uiFont;

    UIKnob attack;
    UIKnob decay;
    UIKnob sustain;
    UIKnob release;

    UIKnob vibAttack;
    UIKnob vibDepth;
    UIKnob vibSpeed;
    
    UIKnob fxNoise;
    UIKnob fxChorus;
    UIKnob fxPorta;

    UIButton polycat;

    UIPonkoVision ponkovision;
    UIPonkoUpdater!UIPonkoVision ponkoupdater;

    Client client;
public:
    this(NuCatSynth synth, Client client) {
        super(makeSizeConstraintsContinuous(480, 320, 0.5, 5));
        _synth = synth;

        // ENV Section
        attack = mallocNew!UIKnob(context, client.param(MEOW_ATTACK));
        attack.setDefaultKnobDesign();

        decay = mallocNew!UIKnob(context, client.param(MEOW_DECAY));
        decay.setDefaultKnobDesign();

        sustain = mallocNew!UIKnob(context, client.param(MEOW_SUSTAIN));
        sustain.setDefaultKnobDesign();

        release = mallocNew!UIKnob(context, client.param(MEOW_RELEASE));
        release.setDefaultKnobDesign();

        // Ponko Display
        ponkovision = mallocNew!UIPonkoVision(context);
        ponkoupdater = mallocNew!(UIPonkoUpdater!UIPonkoVision)(context, ponkovision, synth);

        // Vibrato Section
        vibAttack = mallocNew!UIKnob(context, client.param(MEOW_VIBRATO_ATK));
        vibAttack.setDefaultKnobDesign();
        
        vibDepth = mallocNew!UIKnob(context, client.param(MEOW_VIBRATO_AMNT));
        vibDepth.setDefaultKnobDesign();
        
        vibSpeed = mallocNew!UIKnob(context, client.param(MEOW_VIBRATO_SPEED));
        vibSpeed.setDefaultKnobDesign();

        // FX Section
        fxPorta = mallocNew!UIKnob(context, client.param(MEOW_PORTA));
        fxPorta.setDefaultKnobDesign();

        fxNoise = mallocNew!UIKnob(context, client.param(MEOW_NOISE));
        fxNoise.setDefaultKnobDesign();

        fxChorus = mallocNew!UIKnob(context, client.param(MEOW_CHORUS));
        fxChorus.setDefaultKnobDesign();
        
        // CONFIG section
        polycat = mallocNew!UIButton(context, cast(BoolParameter)client.param(MEOW_POLYCAT));

        this.addChild(attack);
        this.addChild(decay);
        this.addChild(sustain);
        this.addChild(release);
        this.addChild(ponkovision);
        this.addChild(ponkoupdater);
        this.addChild(vibAttack);
        this.addChild(vibDepth);
        this.addChild(vibSpeed);
        this.addChild(fxPorta);
        this.addChild(fxNoise);
        this.addChild(fxChorus);
        this.addChild(polycat);
    }

    override
    void reflow() {
        super.reflow();

        int w = position.width;
        float scale = w / cast(float)(context.getDefaultUIWidth());

        attack.position  = rectangle(248, 58, 49, 49).scaleByFactor(scale);
        decay.position   = rectangle(302, 58, 49, 49).scaleByFactor(scale);
        sustain.position = rectangle(357, 58, 49, 49).scaleByFactor(scale);
        release.position = rectangle(412, 58, 49, 49).scaleByFactor(scale);

        vibAttack.position = rectangle(248, 145, 49, 49).scaleByFactor(scale);
        vibDepth.position  = rectangle(302, 145, 49, 49).scaleByFactor(scale);
        vibSpeed.position  = rectangle(412, 145, 49, 49).scaleByFactor(scale);

        fxPorta.position   = rectangle(248, 234, 49, 49).scaleByFactor(scale);
        fxNoise.position   = rectangle(302, 234, 49, 49).scaleByFactor(scale);
        fxChorus.position  = rectangle(412, 234, 49, 49).scaleByFactor(scale);

        polycat.position    = rectangle(17, 233, 47, 47).scaleByFactor(scale);

        ponkovision.position = rectangle(11, 44, 214, 135).scaleByFactor(scale);
    }
}
