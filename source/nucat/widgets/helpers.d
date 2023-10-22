module nucat.widgets.helpers;
import 
    dplug.core,
    dplug.canvas,
    dplug.pbrwidgets;

import std.algorithm.comparison : clamp, max;

// UI Helpers
nothrow:
@nogc:
void fillBezier(ref Canvas canvas, vec2f A, vec2f control, vec2f B, float lineWidth)
{
    float lw = 0.5f * lineWidth;

    vec2f AC = (control - A);
    vec2f BC = (B - control);

    vec2f rotatedAC = vec2f(0.0f, 0.0f);
    vec2f rotatedBC = vec2f(0.0f, 0.0f);


    if (AC.magnitude() > 1e-6f)
    {
        rotatedAC = vec2f(-AC.y, AC.x).fastNormalized() * lw;
    }
    if (BC.magnitude() > 1e-6f)
    {
        rotatedBC = vec2f(-BC.y, BC.x).fastNormalized() * lw;
    }

    vec2f  controlTop = control + rotatedAC * 0.5f + rotatedBC * 0.5f;
    vec2f  controlBot = control - rotatedAC * 0.5f - rotatedBC * 0.5f;

    canvas.beginPath();
    canvas.moveTo(A.x + rotatedAC.x, A.y + rotatedAC.y);
    canvas.quadraticCurveTo(controlTop.x, controlTop.y - lw, B.x + rotatedBC.x, B.y + rotatedBC.y);
    canvas.lineTo(B.x - rotatedBC.x, B.y - rotatedBC.y);
    canvas.quadraticCurveTo(controlBot.x, controlBot.y + lw, A.x - rotatedAC.x, A.y - rotatedAC.y);
    canvas.fill();
}

void fillLine(ref Canvas canvas, vec2f A, vec2f B, float lineWidth)
{
    float lw = lineWidth * 0.5f;
    vec2f BA = (B - A);
    if (BA.magnitude() < 1e-4f) return;
    BA.fastNormalize();
    vec2f C = A + vec2f(BA.y, -BA.x) * lw;
    vec2f D = A + vec2f(-BA.y, BA.x) * lw;
    vec2f E = B + vec2f(BA.y, -BA.x) * lw;
    vec2f F = B + vec2f(-BA.y, BA.x) * lw;
    canvas.beginPath();
    canvas.moveTo(C.x, C.y);
    canvas.lineTo(D.x, D.y);
    canvas.lineTo(F.x, F.y);
    canvas.lineTo(E.x, E.y);
    canvas.fill();
}

void fillHorizontalLine(ref Canvas canvas, float x1, float x2, float y, float lineWidth)
{
    float lw = 0.5f * lineWidth;
    canvas.beginPath();
    canvas.moveTo(x1, y - lw);
    canvas.lineTo(x2, y - lw);
    canvas.lineTo(x2, y + lw);
    canvas.lineTo(x1, y + lw);
    canvas.fill();
}

void fillVerticalLine(ref Canvas canvas, float x, float y1, float y2, float lineWidth)
{
    float lw = 0.5f * lineWidth;
    canvas.beginPath();
    canvas.moveTo(x - lw, y1);
    canvas.lineTo(x + lw, y1);
    canvas.lineTo(x + lw, y2);
    canvas.lineTo(x - lw, y2);
    canvas.fill();
}

void square(ref Canvas canvas, float x, float y, float s1, float s2)
{
    canvas.beginPath();
    canvas.moveTo(x - s1, y - s1 );
    canvas.lineTo(x + s1, y - s1 );
    canvas.lineTo(x + s2, y - s2 );
    canvas.lineTo(x - s2, y - s2 );
    canvas.moveTo(x - s1, y + s1 );
    canvas.lineTo(x + s1, y + s1 );
    canvas.lineTo(x + s2, y + s2 );
    canvas.lineTo(x - s2, y + s2 );
    canvas.moveTo(x - s1, y - s1);
    canvas.lineTo(x - s1, y + s1);
    canvas.lineTo(x - s2, y + s2);
    canvas.lineTo(x - s2, y - s2);
    canvas.moveTo(x + s1, y - s1);
    canvas.lineTo(x + s1, y + s1);
    canvas.lineTo(x + s2, y + s2);
    canvas.lineTo(x + s2, y - s2);
    canvas.fill();
}

void roundRect(ref Canvas canvas, float x, float y, float w, float h, float radius) {
    
        float left = x;
        float right = x+w;
        float top = y;
        float bottom = y+h;

        canvas.beginPath();
        canvas.moveTo(left+radius, top);

        // TOP
        canvas.lineTo(right-radius, top);
        canvas.quadraticCurveTo(right, top, right, top+radius);

        // RIGHT
        canvas.lineTo(right, bottom-radius);
        canvas.quadraticCurveTo(right, bottom, right-radius, bottom);

        // BOTTOM
        canvas.lineTo(top+radius, bottom);
        canvas.quadraticCurveTo(left, bottom, left, bottom-radius);

        // LEFT
        canvas.lineTo(left, top+radius);
        canvas.quadraticCurveTo(left, top, left+radius, top);
        
        canvas.closePath();
        canvas.fill();
}

void waveform(ref Canvas canvas, float lineWidth, float x, float y, float w, float h, float[] waveform) {
    float lw = lineWidth * 0.5f;

    float h2 = h/2;
    float yoffset = y+h2;
    float pw = w*(1.0/cast(float)waveform.length);

    vec2f start = vec2f(x, yoffset+(waveform[0]*h2));
    vec2f stop = vec2f(x+w, yoffset+(waveform[$-1]*h2));

    canvas.beginPath();
    canvas.moveTo(start);

    for (int k = 1; k + 1 < waveform.length; ++k)
    {
        float pk = start.x+(pw*(k-1));
        float ik = start.x+(pw*k);
        float nk = start.x+(pw*(k+1));

        // Pa and Pb are the line cap points.
        //
        //   Pb--Pa-----------
        //  /  P--------------A
        // /  /
        //   /
        //  B
        vec2f B = vec2f(pk, yoffset+(waveform[k-1]*h2));
        vec2f P = vec2f(ik, yoffset+(waveform[k]*h2));
        vec2f A = vec2f(nk, yoffset+(waveform[k+1]*h2));
        vec2f PA = (A - P).fastNormalized;
        vec2f PB = (B - P).fastNormalized;

        canvas.lineTo(P + vec2f(-PB.y*lw, PB.x*lw)); // Pb
        canvas.lineTo(P + vec2f(PA.y*lw, -PA.x*lw)); // Pa

    }

    canvas.lineTo(stop);
    for (int k = cast(int)waveform.length - 2; k > 0; --k)
    {
        float pk = start.x+(pw*(k-1));
        float ik = start.x+(pw*k);
        float nk = start.x+(pw*(k+1));

        vec2f B = vec2f(pk, yoffset+(waveform[k-1]*h2));
        vec2f P = vec2f(ik, yoffset+(waveform[k]*h2));
        vec2f A = vec2f(nk, yoffset+(waveform[k+1]*h2));
        vec2f PA = (A - P).fastNormalized;
        vec2f PB = (B - P).fastNormalized;

        canvas.lineTo(P - vec2f(PA.y*lw, -PA.x*lw)); // Pa2
        canvas.lineTo(P - vec2f(-PB.y*lw, PB.x*lw)); // Pb2
    }
    canvas.lineTo(start);
    canvas.fill();
}

void setDefaultKnobDesign(ref UIKnob knob) {
    knob.style = KnobStyle.cylinder;
    knob.numLEDs = 1;
    knob.LEDMaterial = RGBA(255, 165, 0, 128);
    knob.LEDDiffuseLit = RGBA(230, 80, 43, 192);
    knob.LEDDiffuseUnlit = RGBA(150, 40, 20, 8);
    knob.LEDDepth = 100;
    knob.knobRadius = 0.40;
    knob.trailRadiusMin = 0.55;
    knob.trailRadiusMax = 0.80;
    knob.LEDDistanceFromCenterDragged = knob.LEDDistanceFromCenter;
}