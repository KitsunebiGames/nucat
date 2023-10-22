module nucat.common;
import std.math;

/**
    TAU (2 * PI)
*/
enum TAU = 2 * PI;

/**
    A parameter
*/
alias NuCatParam = int;

/**
    The maximum polyphony
*/
enum NUCAT_MAX_POLY = 16;

/**
    Internal gain
*/
enum NUCAT_I_GAIN = (1.0 / (NUCAT_MAX_POLY / SQRT1_2)) * (NUCAT_MAX_POLY/2);

/**
    Wavetable synth param
*/
enum : NuCatParam {

    MEOW_ATTACK,
    MEOW_DECAY,
    MEOW_SUSTAIN,
    MEOW_RELEASE,

    MEOW_VIBRATO_AMNT,
    MEOW_VIBRATO_ATK,
    MEOW_VIBRATO_SPEED,

    MEOW_PORTA,
    MEOW_NOISE,
    MEOW_CHORUS,
    MEOW_PB,

    MEOW_POLYCAT
}