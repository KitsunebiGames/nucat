module nucat.fx;
import ddsp.effect;
import dplug.core;
import std.math;
import std.algorithm.comparison;

class SineOsc(T) {
nothrow:
@nogc:
private:
    float phase = 0;
    float deltaPhase = 0;
    float rate = 0;
    float depth = 1;

    void recalculateDelta() {
        this.deltaPhase = (rate * TAU / _sampleRate);
    }

public:
    void setSampleRate(float sampleRate) {
        _sampleRate = sampleRate;
        this.recalculateDelta();
    }

    T getNextSample() {
        phase += deltaPhase;
        while(phase >= TAU) phase -= TAU;

        return fast_sin(phase)*depth;
    }

    void setParams(float rate, float depth) {
        this.rate = rate;
        this.depth = depth;
        this.recalculateDelta();
    }

    void reset() {
        phase = 0;
    }
}

class BetterModDelay(T) : AudioEffect!T {
nothrow:
@nogc:
private:
    DigitalDelay!T delay;
    SineOsc!T lfo;

    T _mod_rate;
    T _mod_depth;
    T _mix;
    T _feedback;
    T _delay_offset;

    T _max_delay;
    T _min_delay;

public:
    this() {
        lfo = mallocNew!(SineOsc!T)();
        delay = mallocNew!(DigitalDelay!T)();
    }

    override
    void setSampleRate(float sampleRate) {
        _sampleRate = sampleRate;
        lfo.setSampleRate(sampleRate);
        delay.setSampleRate(sampleRate);
    }

    float calcDelayOffset(float lfoValue) {
        float startDelay = _min_delay + _delay_offset;
        float lfoOffset = _mod_depth * ((lfoValue + 1) / 2 * (_max_delay - _min_delay)) + _min_delay;
        return max(lfoOffset + startDelay, 0);
    }

    /// Must be set before processing audio
    void setDelayRange(float minDelay, float maxDelay) {
        _min_delay = minDelay;
        _max_delay = maxDelay;
    }

    void setParams(float rate, float depth, float mix, float feedback, int offset) {
        _mod_rate = rate;
        _mod_depth = depth;
        _delay_offset = offset;
        _feedback = feedback;
        _mix = mix;

        //Frequency, sin, not bandlimited
        lfo.setParams(rate, 1);
        delay.setParams(0, feedback, mix);
    }

    override
    T getNextSample(const T input) {
        float fYn = lfo.getNextSample();
        float delaySamples = calcDelayOffset(fYn);
        
        delay.setParams(delaySamples, _feedback, _mix);
        float output = delay.getNextSample(input);
        return output;
    }

    override
    void reset() {
        lfo.reset();
        delay.reset();
    }
}

class BetterVibrato(T) : AudioEffect!T {
nothrow:
@nogc:
private:
    BetterModDelay!T _modDelay;

public:

    this() {
        _modDelay = mallocNew!(BetterModDelay!T)();
    }

	override void setSampleRate(float sampleRate) {
		_sampleRate = sampleRate;
		_modDelay.setSampleRate(_sampleRate);
		_modDelay.setDelayRange(0, 7);
	}

    void setParams(float modRate, float modDepth) {
        _modDelay.setParams(modRate, modDepth, 1.0, 0.0, 0);
    }

    override T getNextSample(const T input) {
        return _modDelay.getNextSample(input);
    }

    override void reset() {
        _modDelay.reset();
    }
}


class BetterChorus(T) : AudioEffect!T {
nothrow:
@nogc:
private:
    BetterModDelay!T _modDelay;

public:
    this() {
        _modDelay = mallocNew!(BetterModDelay!T)();
    }

	override void setSampleRate(float sampleRate) {
		_sampleRate = sampleRate;
		_modDelay.setSampleRate(_sampleRate);
		_modDelay.setDelayRange(5, 30);
	}

    void setParams(float modRate, float modDepth) {
        _modDelay.setParams(modRate, modDepth, 0.5, 0.0, 0);
    }

    override
    T getNextSample(const T input) {
        return _modDelay.getNextSample(input);
    }

    override
    void reset() {
        _modDelay.reset();
    }
}