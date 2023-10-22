module nucat.synth;
import dplug.core, dplug.client;
import std.math;
import dplug.core.random;
import std.random : Xorshift32;

import ddsp.filter;
import ddsp.effect;

import 
    nucat.common, 
    nucat.voice,
    nucat.adsr;


/**
    A meowizer
*/
class NuCatSynth {
nothrow:
@nogc:
private:

    Voice[NUCAT_MAX_POLY] _voices;

    ADSR ponkoadsr;
    int playing;

    float noiseGain;

    Chorus!float chorus;

public:
    this() {
        foreach(i; 0..NUCAT_MAX_POLY) {
            _voices[i] = mallocNew!Voice();
        }

        ponkoadsr = ADSR.createNew();
        chorus = mallocNew!(Chorus!float)();
    }

    /**
        Gets whether the synth is playing
    */
    bool isPlaying() {
        foreach(ref wt; _voices) {
            if (wt.isPlaying) return true;
        }
        return false;
    }

    /**
        Resets the synth
    */
    void reset(float sampleRate) {
        foreach(i, ref voice; _voices) voice.reset(sampleRate);
        ponkoadsr.reset(sampleRate);
        this.releaseAll!true;

        chorus.reset();
        chorus.setSampleRate(sampleRate);
    }

    /**
        Updates the synth
    */
    void update(Client client) {

        foreach(ref voice; _voices) {
            
            // TODO: Use listeners?
            voice.adsr.setAttack(client.readParam!float(MEOW_ATTACK)+0.01);
            voice.adsr.setDecay(client.readParam!float(MEOW_DECAY)+0.01);
            voice.adsr.setSustain(client.readParam!float(MEOW_SUSTAIN));
            voice.adsr.setRelease(client.readParam!float(MEOW_RELEASE)+0.01);

            voice.setVibratoAttack(client.readParam!float(MEOW_VIBRATO_ATK));
            voice.setVibratoDepth(client.readParam!float(MEOW_VIBRATO_AMNT));
            voice.setVibratoRate(client.readParam!float(MEOW_VIBRATO_SPEED));

        }
        chorus.setParams(0.5, client.readParam!float(MEOW_CHORUS));
        

        ponkoadsr.setAttack(client.readParam!float(MEOW_ATTACK)+0.01);
        ponkoadsr.setDecay(client.readParam!float(MEOW_DECAY)+0.01);
        ponkoadsr.setSustain(client.readParam!float(MEOW_SUSTAIN));
        ponkoadsr.setRelease(0.1);

        noiseGain = client.readParam!float(MEOW_NOISE);
    }

    /**
        Applies pitchbend
    */
    void pitchbend(float bend) {
        foreach(ref voice; _voices) voice.pitchbend(bend);
    }

    /**
        Plays a note with the wavetable
    */
    void playNote(int note, float velocity = 1) {
        
        ponkoadsr.kill();
        ponkoadsr.play();

        // First try finding a silent, non-playing voice
        ptrdiff_t fReleased = -1;
        foreach(i, ref v; _voices) {  

            // Retrigger
            if (v.getNote() == note) {
                if (!v.adsr.getGate()) {
                    playing++;
                }
                v.play(note, velocity);
                return;
            }

            if (!v.isPlaying) {

                // Store the first non-playing voice
                if (fReleased < 0) fReleased = i;

                // Only try replacing voices which are not playing,
                // And which has ended their ADSR envelope cycle
                if (!v.adsr.getGate() && v.adsr.getState() == ADSRState.idle) {
                    v.play(note, velocity);
                    playing++;
                    return;
                }
            }
        }

        // Replace the first non-playing voice
        // If that fails we're out of voices and we'll stay silent.
        if (fReleased >= 0) {
            _voices[fReleased].play(note, velocity);
        }
    }

    /**
        Releases a note
    */
    void releaseNote(int note) {
        foreach(ref v; _voices) {
            if (v.isPlaying() && v.getNote == note) {
                v.release();
                playing--;
                return;
            }
        }
    }

    /**
        Releases all notes
    */
    void releaseAll(bool soundCut)() {
        foreach(ref v; _voices) {
            static if (soundCut) v.kill();
            else v.release();
        }
        
        playing = 0;
        ponkoadsr.release();
    }

    /**
        Synthesis function
    */
    void synthesize(float*[] outputs, int frames, double dt) {

        if (playing == 0 && ponkoadsr.isPlaying && !ponkoadsr.isReleasing) {
            ponkoadsr.release();
        }

        foreach(ref sample; outputs[0][0..frames]) {

            float pnkenv = ponkoadsr.nextSample();

            float output = 0;
            float v = 0;
            foreach(ref voice; _voices) {
                if (voice.isPlaying) {
                    output += voice.nextSample();
                    v++;
                }
            }

            sample = chorus.getNextSample(output) * NUCAT_I_GAIN;

            if (noiseGain > 0 && playing > 0) {
                float noise = (nogc_uniform_float(0, 1, defaultGlobalRNG())*noiseGain);
                sample += (noise * pnkenv) * NUCAT_I_GAIN;
            }
            
        }

        // Copy to other channels
        foreach(c; 1..outputs.length) {
            outputs[c][0 .. frames] = outputs[0][0 .. frames];
        }
    }

    float getPonkoADSR() {
        return ponkoadsr.getOutputAtomic;
    }
}