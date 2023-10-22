module nucat.voice;

import nucat.adsr;
import dplug.core;
import std.math;

import ddsp.util.envelope;
import dplug.dsp.iir;
import std.algorithm.comparison;

import ddsp.filter;
import ddsp.effect;

class Voice {
@nogc:
nothrow:
private:
    float sampleRate = 0;
    ADSR envelope;
    BiquadDelay lp;
    BiquadDelay bell;
    
    int note;
    float velocity = 0;
    float deltaPhase = 0;
    float bend = 0;

    void recalculateDelta() {
        this.deltaPhase = (freq * TAU / sampleRate);
    }
public:
    float freq = 0;
    float phase = 0;

    this() {
        envelope = ADSR.createNew();
        lp.initialize();
        bell.initialize();
    }

    /**
        ニャ～
    */
    void play(int note, float velocity = 1) {
        this.note = note;
        this.velocity = velocity;
        
        if (envelope.isPlaying()) {
            envelope.kill();
        }
        
        envelope.play();
        this.freq = convertMIDINoteToFrequency(this.note+(this.bend*12));
        this.recalculateDelta();
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
    }

    /**
        Pitchbend the current meow

        TODO: load bend factor from parameters
    */
    void pitchbend(float bend) {
        this.bend = bend;
        this.freq = convertMIDINoteToFrequency(cast(float)this.note+(this.bend*12.0));
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
        phase += deltaPhase;
        while(phase >= TAU) phase -= TAU;

        // Vocal chords are essentially pure saw waves
        // Like a bowed string instrument
        // We update the envelope and the next Saw entry
        float env = envelope.nextSample();
        float saw = rawSawtooth(phase);
        
    
        // As velocity lowers the meows should be softer
        // As such the logarithmic mapping needs to be
        // scrubbed between.
        auto lpFreq = logmap(
            velocity, 
            logmap(env, 100.0, 700.0), 
            logmap(env, 400.0, 1600.0)
        );

        // We filter the meow in 2 steps;
        // 1. A low pass filter with a lot of resonance.
        // 2. A peak filter at 5000 Hz to cut any raw saw
        //    that may have sneaked through the first filter.
        // After this the output volume is adjusted by the ADSR envelope and key velocity.
        // TODO: Add aftertouch?
        auto coeff = biquadRBJLowPass(lpFreq, sampleRate, 6.2);
        auto bellCoeff = biquadRBJPeak(5000, sampleRate, -10, 1.5);

        auto fSample = bell.nextSample(lp.nextSample(saw, coeff), bellCoeff)*(env*velocity);
        return fSample;
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