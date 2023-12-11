module nucat.plugin;
import 
    dplug.core, 
    dplug.client;

import 
    nucat.ui, 
    nucat.synth, 
    nucat.common,
    nucat.widgets;

final class NuCatClient : Client {
nothrow:
@nogc:
private:
    NuCatSynth _synth;
    double _sampleRate;

public:
    this() {
        _synth = mallocNew!NuCatSynth;
    }

    override
    PluginInfo buildPluginInfo() {
        static immutable(PluginInfo) info = parsePluginInfo(import("plugin.json"));
        return info;
    }

    override
    IGraphics createGraphics() {
        return mallocNew!WavetableSynthInterface(_synth, this);
    }

    override
    Parameter[] buildParameters() {
        auto params = makeVec!Parameter;
        params ~= mallocNew!LinearFloatParameter(MEOW_ATTACK, "Attack", "Attack", 0.0, 1.0, 0.19);
        params ~= mallocNew!LinearFloatParameter(MEOW_DECAY, "Decay", "Decay", 0.0, 1.0, 0.45);
        params ~= mallocNew!LinearFloatParameter(MEOW_SUSTAIN, "Sustain", "Sustain", 0.0, 1, 0.5);
        params ~= mallocNew!LinearFloatParameter(MEOW_RELEASE, "Release", "Release", 0.0, 1.0, 0);

        params ~= mallocNew!LinearFloatParameter(MEOW_VIBRATO_AMNT, "VibratoDpt", "Vibrato Depth", 0.0, 1.0, 0);
        params ~= mallocNew!LinearFloatParameter(MEOW_VIBRATO_ATK, "VibratoAtk", "Vibrato Attack", 0.0, 1.0, 0);
        params ~= mallocNew!LinearFloatParameter(MEOW_VIBRATO_SPEED, "VibratoSpd", "Vibrato Speed", 0.0, 1.0, 0);

        params ~= mallocNew!LinearFloatParameter(MEOW_PORTA, "Porta", "Portamento", 0.0, 1.0, 0);
        params ~= mallocNew!LinearFloatParameter(MEOW_NOISE, "Noise", "Noise", 0.0, 1.0, 0);
        params ~= mallocNew!LinearFloatParameter(MEOW_CHORUS, "Chorus", "Chorus", 0.0, 1.0, 0);
        params ~= mallocNew!IntegerParameter(MEOW_PB, "Pitchbend", "Pitchbend", 0, 12, 1);

        params ~= mallocNew!BoolParameter(MEOW_POLYCAT, "Poly Cat", true);
        
        return params.releaseData();
    }

    override
    LegalIO[] buildLegalIO() {
        auto io = makeVec!LegalIO;
        io ~= LegalIO(0, 1);
        io ~= LegalIO(0, 2);
        return io.releaseData();
    }

    /**
        Returns the maximum number of frames in flight
    */
    override
    int maxFramesInProcess() {
        return 128;
    }

    override
    void reset(double sampleRate, int maxFrames, int numInputs, int numOutputs) {
        _sampleRate = sampleRate;
        _synth.reset(sampleRate);
    }

    override
    void processAudio(const(float*)[] inputs, float*[] outputs, int frames, TimeInfo info) {
        
        double dt = cast(double)(frames)/_sampleRate;

        // Voices may use info from the update,
        // Therefore we need to update before processing voice changes.
        _synth.update(this);
        
        // Handle messages
        foreach(msg; getNextMidiMessages(frames)) {
            if (msg.isNoteOn) {

                // Note was played
                _synth.playNote(msg.noteNumber, msg.noteVelocity/127.0);
            } else if (msg.isNoteOff) {

                // Note was released
                _synth.releaseNote(msg.noteNumber);
            } else if (msg.isPitchBend) {

                // Pitchbend was applied
                _synth.pitchbend(msg.pitchBend);
            } else if (msg.isAllNotesOff) {

                // All notes were released
                _synth.releaseAll!false();
            } else if (msg.isAllSoundsOff) {

                // All sounds were stopped
                // In this case kill audio immediately.
                _synth.releaseAll!true();
            }
        }

        _synth.synthesize(outputs, frames, dt);
    }
}

// Create plugin entry points
mixin(pluginEntryPoints!NuCatClient);