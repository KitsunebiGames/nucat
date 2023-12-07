module nucat.voice;

import dplug.core;
import std.math;

import ddsp.util.envelope;
import dplug.dsp.iir;
import std.algorithm.comparison;

import ddsp.filter;
import ddsp.effect;

import kon.generators.basic;
import kon.env.adsr;

class Voice {
@nogc:
nothrow:
private:
    float sampleRate = 0;
    ADSR envelope;
    BiquadDelay lp;
    BiquadDelay bell;
    KonPolyBLEPOSC!float osc;
    
    int note;

    float velocity = 0;
    float bend = 0;
    float bendDepth = 12;

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
    }

    /**
        ニャ～
    */
    void play(int note, float velocity = 1) {
        if (!envelope.getGate) envelope.play();

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
        envelope.reset(sampleRate);
        lp.initialize();
        bell.initialize();
        this.recalculateDelta();
        osc.setSampleRate(sampleRate);
        osc.reset();
    }

    /**
        Pitchbend the current meow

        TODO: load bend factor from parameters
    */
    void pitchbend(float bend) {
        this.bend = bend;
        this.freq = convertMIDINoteToFrequency(cast(float)this.note+(this.bend*bendDepth));

        // Handle porta
        if (this.portaNote >= 0) {
            this.portaFreq = convertMIDINoteToFrequency(cast(float)this.portaNote+(this.bend*bendDepth));
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
        
    
        // As velocity lowers the meows should be softer
        // As such the logarithmic mapping needs to be
        // scrubbed between.
        auto lpFreq = logmap(
            velocity, 
            logmap(env, 100.0, 700.0), 
            logmap(env, 400.0, 1800.0)
        );

        // We filter the meow in 2 steps;
        // 1. A low pass filter with a lot of resonance.
        // 2. A peak filter at 5000 Hz to cut any raw saw
        //    that may have sneaked through the first filter.
        // After this the output volume is adjusted by the ADSR envelope and key velocity.
        // TODO: Add aftertouch?
        auto coeff = biquadRBJLowPass(lpFreq, sampleRate, 3);
        // auto bellCoeff = biquadRBJPeak(7000, sampleRate, -10, 1.5);
        auto msample = lp.nextSample(saw, coeff);

        // auto fSample = bell.nextSample(msample, bellCoeff);

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