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

    // porta mode
    float t = 0;
    float deltaT = 0;
    float targetDeltaPhase = 0;
    int portaNote = -1;
    float portaFreq = 0;
    float portaAttack = 0;

    void recalculateDelta() {
        this.deltaPhase = (freq * TAU / sampleRate);
        this.targetDeltaPhase = (portaFreq * TAU / sampleRate);
        this.deltaT = 1/sampleRate;
    }

    /**
        Gets the current delta phase
    */
    float getCurrentDeltaPhase() {
        if (portaNote >= 0) {
            return portaAttack > 0 ? 
                   lerp(deltaPhase, targetDeltaPhase, clamp(t/portaAttack, 0, 1)) : 
                   targetDeltaPhase;
        }
        return deltaPhase;
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
        Sets porta target
    */
    void portaTo(int note) {
        float newStartFreq = getCurrentFreq();
        float newStartDelta = getCurrentDeltaPhase();

        this.portaNote = note;
        this.portaFreq = convertMIDINoteToFrequency(portaNote+(this.bend*12));
        this.t = 0;

        // Handle delta phase
        this.recalculateDelta();
        this.freq = newStartFreq;
        this.deltaPhase = newStartDelta;
    }

    void setPortaAttack(float attack) {
        this.portaAttack = attack;
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

        // Handle porta
        if (this.portaNote >= 0) {
            this.portaFreq = convertMIDINoteToFrequency(cast(float)this.portaNote+(this.bend*12.0));
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
        float cPhase = getCurrentDeltaPhase();

        // Portamento timer
        t += deltaT;

        // Portamento phase handling
        if (portaNote >= 0 && cPhase == targetDeltaPhase) {
            this.note = portaNote;
            this.deltaPhase = targetDeltaPhase;

            this.portaNote = -1;
        }

        phase += cPhase;
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