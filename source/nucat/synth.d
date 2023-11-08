module nucat.synth;
import dplug.core, dplug.client;
import std.math;
import dplug.core.random;
import std.random : Xorshift32;
import std.algorithm.comparison;

import ddsp.filter;
import ddsp.effect;

import kon.env.adsr;

import 
    nucat.common, 
    nucat.voice,
    nucat.fx;


/**
    A meowizer
*/
class NuCatSynth {
nothrow:
@nogc:
private:

    Voice[NUCAT_MAX_POLY] _voices;

    size_t heldI;
    int[NUCAT_MAX_POLY] _heldNotes;

    ADSR ponkoadsr;
    int playing;

    float noiseGain;

    // T delta
    float tDelta = 0;
    float t = 0;
    
    // Vibrato
    float vibratoAttack = 0;
    float vibratoRate = 0;
    float vibratoDepth = 0;

    // FX Section
    BetterChorus!float chorus;
    BetterVibrato!float vibrato;

    bool polyPath;
    float porta;
    int pnote;

public:
    this() {
        foreach(i; 0..NUCAT_MAX_POLY) {
            _voices[i] = mallocNew!Voice();
        }

        ponkoadsr = ADSR.createNew();
        chorus = mallocNew!(BetterChorus!float)();
        vibrato = mallocNew!(BetterVibrato!float)();
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

        vibrato.reset();
        vibrato.setSampleRate(sampleRate);

        tDelta = 1/sampleRate;
    }

    /**
        Updates the synth
    */
    void update(Client client) {

        porta = client.readParam!float(MEOW_PORTA);

        foreach(ref voice; _voices) {
            
            // TODO: Use listeners?
            voice.adsr.setAttack(client.readParam!float(MEOW_ATTACK)+0.01);
            voice.adsr.setDecay(client.readParam!float(MEOW_DECAY)+0.01);
            voice.adsr.setSustain(client.readParam!float(MEOW_SUSTAIN));
            voice.adsr.setRelease(client.readParam!float(MEOW_RELEASE)+0.01);

            voice.setPortaAttack(porta);
        }

        chorus.setParams(client.readParam!float(MEOW_CHORUS), 1);

        this.vibratoAttack = client.readParam!float(MEOW_VIBRATO_ATK);
        this.vibratoDepth = client.readParam!float(MEOW_VIBRATO_AMNT);
        this.vibratoRate = client.readParam!float(MEOW_VIBRATO_SPEED);

        ponkoadsr.setAttack(client.readParam!float(MEOW_ATTACK)+0.01);
        ponkoadsr.setDecay(client.readParam!float(MEOW_DECAY)+0.01);
        ponkoadsr.setSustain(client.readParam!float(MEOW_SUSTAIN));
        ponkoadsr.setRelease(client.readParam!float(MEOW_RELEASE)+0.01);

        noiseGain = client.readParam!float(MEOW_NOISE);

        polyPath = client.readParam!bool(MEOW_POLYCAT);
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

        if (polyPath) {
        
            ponkoadsr.kill();
            ponkoadsr.play();

            // First try finding a silent, non-playing voice
            ptrdiff_t fReleased = -1;
            foreach(i, ref v; _voices) {  

                // Retrigger
                if (v.getNote() == note) {
                    if (!v.adsr.getGate()) {
                        playing++;
                        
                        if (playing == 1) t = 0;
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
                        
                        if (playing == 1) t = 0;
                        return;
                    }
                }
            }
            

            // Replace the first non-playing voice
            // If that fails we're out of voices and we'll stay silent.
            if (fReleased >= 0) {
                _voices[fReleased].play(note, velocity);
            }
        } else {

            if (!_voices[0].isPlaying()) {
                ponkoadsr.play();
            }

            if (playing+1 < NUCAT_MAX_POLY) {
                pnote = note;
                if (porta > 0) {
                    
                    // Portamento-to
                    if (!_voices[0].isPlaying) {
                        _voices[0].play(note, velocity);
                    } else {
                        _voices[0].portaTo(note);
                    }
                    
                    _heldNotes[playing++] = note;
                } else {
                    _voices[0].play(note, velocity);
                    _heldNotes[playing++] = note;
                }
            }

        }
    }

    /**
        Releases a note
    */
    void releaseNote(int note) {
        if (polyPath) {
            foreach(ref v; _voices) {
                if (v.isPlaying() && v.getNote == note) {
                    v.release();
                    playing--;
                    return;
                }
            }
        } else {

            // Find released note in list
            ptrdiff_t hn = -1;
            foreach(i, hnote; _heldNotes) {
                if (hnote == note) {
                    hn = i;
                }
            }

            // Note was found, release it, and pop it
            if (hn >= 0) {

                // Move everything to the right after the held note
                // this will update the list.
                if (hn < playing) {
                    _heldNotes[hn..playing] = _heldNotes[hn+1..playing];
                }
                
                playing--;

                // Play the last note in the held list
                if (playing > 0) {
                    
                    if (porta > 0) {
                        if (_heldNotes[playing-1] != pnote) {
                            pnote = _heldNotes[playing-1];
                            _voices[0].portaTo(_heldNotes[playing-1]);
                        }
                    } else {
                        if (_heldNotes[playing-1] != pnote) {
                            pnote = _heldNotes[playing-1];
                            _voices[0].play(_heldNotes[playing-1]);
                        }
                    }
                } else {
                    pnote = -1;
                    _voices[0].release();
                }
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
        heldI = 0;
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
            this.t += tDelta;

            float pnkenv = ponkoadsr.nextSample();

            float output = 0;
            float v = 0;
            foreach(ref voice; _voices) {
                if (voice.isPlaying) {
                    output += voice.nextSample();
                    v++;
                }
            }
            
            // In case vibrato is turned on, linear 
            // interpolate between the normal sample 
            // and the vibrato'd sample.
            // float vt = clamp(vibratoAttack > 0 ? t/vibratoAttack : 1, 0, 1);
            // vibrato.setParams(this.vibratoRate*5, lerp(0, this.vibratoDepth, vt));
            // output = vibrato.getNextSample(output); 
            
            // TODO: Redo chorus and vibrato

            // Chorus
            sample = output * NUCAT_I_GAIN;

            // Noise
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
        return ponkoadsr.getOutput;
    }
}