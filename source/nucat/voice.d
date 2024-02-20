module nucat.voice;

import dplug.core;
import std.math;

import dplug.dsp.iir;
import std.algorithm.comparison;

import kon.generators.basic;
import kon.fx.moddelay;
import kon.env.adsr;

class Voice {
@nogc:
nothrow:
private:
    float sampleRate = 0;
    ADSR envelope;

    // Filters
    BiquadDelay lp;
    BiquadDelay bell;

    // Oscillator
    KonPolyBLEPOSC!float osc;
    
    // Note data
    int note;
    float velocity = 0;
    float bend = 0;
    float bendDepth = 12;

    // Vibrato
    KonVibrato!float vibrato;
    float vibratoTime = 0;      // Counter
    float vibratoAttack = 1;    // Counter Time
    float vibratoRate = 0;      // Rate
    float vibratoDepth = 0;     // Depth


    // porta mode
    float t = 0;
    float deltaT = 0;
    int portaNote = -1;
    float portaFreq = 0;
    float portaAttack = 0;

    void recalculateDelta() {
        osc.setFrequency(freq);
        this.deltaT = 1/sampleRate;
    }

    /**
        Gets the current frequency
    */
    float getCurrentFreq() {
        if (portaNote >= 0) {
            return portaAttack > 0 ? 
                   lerp(freq, portaFreq, clamp(t/portaAttack, 0, 1)) : 
                   portaFreq;
        }
        return freq;
    }

public:
    float freq = 0;
    float phase = 0;

    this() {
        envelope = ADSR.createNew();
        lp.initialize();
        bell.initialize();

        // Oscillator
        osc = mallocNew!(KonPolyBLEPOSC!float)();
        osc.setShape(BasicOSCShape.saw);

        vibrato = mallocNew!(KonVibrato!float)();
    }

    /**
        ニャ～
    */
    void play(int note, float velocity = 1) {
        if (!envelope.getGate) envelope.play();

        this.vibratoTime = 0;
        this.note = note;
        this.velocity = velocity;
        this.freq = convertMIDINoteToFrequency(this.note+(this.bend*bendDepth));
        this.recalculateDelta();
    }

    /**
        Sets porta target
    */
    void portaTo(int note) {
        float newStartFreq = getCurrentFreq();

        this.portaNote = note;
        this.portaFreq = convertMIDINoteToFrequency(portaNote+(this.bend*bendDepth));
        this.t = 0;

        // Handle delta phase
        this.recalculateDelta();
        this.freq = newStartFreq;
    }

    /**
        Sets the vibrato parameters.
    */
    void setVibratoParams(float attack, float depth, float rate) {
        this.vibratoAttack = attack;
        this.vibratoDepth = depth;
        this.vibratoRate = rate*5.0;
    }

    /**
        Set portamento attack
    */
    void setPortaAttack(float attack) {
        this.portaAttack = attack;
    }

    /**
        Sets the depth of pitchbend
    */
    void setPitchBendDepth(float depth) {
        bendDepth = depth;
    }

    /**
        Stop meowing, instantly
    */
    void kill() {
        envelope.kill();
    }

    /**
        Stop meowing
    */
    void release() {
        envelope.release();
    }

    /**
        Reset state
    */
    void reset(float sampleRate) {
        this.sampleRate = sampleRate;

        // Update OSC
        osc.setSampleRate(sampleRate);
        osc.reset();

        // Update env and delta
        envelope.reset(sampleRate);
        this.recalculateDelta();

        // Update filters and FX
        lp.initialize();
        bell.initialize();
        vibrato.setSampleRate(sampleRate);
    }

    /**
        Pitchbend the current meow

        TODO: load bend factor from parameters
    */
    void pitchbend(float bend) {
        this.bend = bend;
        this.freq = convertMIDINoteToFrequency(cast(float)this.note+(bendDepth*this.bend));

        // Handle porta
        if (this.portaNote >= 0) {
            this.portaFreq = convertMIDINoteToFrequency(cast(float)this.portaNote+(bendDepth*this.bend));
        }
        this.recalculateDelta();
    }

    /**
        Whether a meow is ongoing
    */
    bool isPlaying() {
        return envelope.isPlaying();
    }

    /**
        Whether the meow is being released
    */
    bool isReleasing() {
        return envelope.getState() == ADSRState.release;
    }

    /**
        Calculates the next sample in the meow
    */
    float nextSample() {
        float currFreq = getCurrentFreq();
        osc.setFrequency(currFreq);

        // Portamento timer
        t += deltaT;

        // Vibrato timer
        vibratoTime += deltaT;

        // Portamento phase handling
        if (portaNote >= 0 && currFreq == portaFreq) {
            this.note = portaNote;
            this.freq = portaFreq;

            this.portaNote = -1;
        }

        // Vocal chords are essentially pure saw waves
        // Like a bowed string instrument
        // We update the envelope and the next Saw entry
        float env = envelope.nextSample();
        float saw = osc.nextSample();
        

        // Do vibrato if depth is over 0
        if (vibratoDepth > 0) {
            
            float vt = clamp(vibratoAttack > 0 ? vibratoTime/vibratoAttack : 1, 0, 1);
            vibrato.setRate(this.vibratoRate);
            vibrato.setDepth(lerp(0, this.vibratoDepth, vt));
            saw = vibrato.nextSample(saw);
        }
    
        // As velocity lowers the meows should be softer
        // As such the logarithmic mapping needs to be
        // scrubbed between.
        auto lpFreq = logmap(
            velocity, 
            logmap(env, 100.0, 700.0), 
            logmap(env, 400.0, 2400.0)
        );

        // We filter the meow with a low pass filter with a lot of resonance.
        // After this the output volume is adjusted by the ADSR envelope and key velocity.
        // TODO: Add aftertouch?
        float lpq = lerp(2.0, 4.0, env);
        auto coeff = biquadRBJLowPass(lpFreq, sampleRate, lpq);
        auto msample = lp.nextSample(saw, coeff);

        auto fSample = msample;
        return fSample*(env*velocity);
    }

    /**
        Gets the tuned note we're meowing at
    */
    int getNote() {
        return note;
    }

    /**
        Returns the active ADSR envelope for the voice
    */
    ref ADSR adsr() {
        return envelope;
    }
}