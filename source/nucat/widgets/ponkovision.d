/**
    Animated ponko display
*/
module nucat.widgets.ponkovision;
import std.math;
import dplug.gui.element;
import dplug.core.math;
import dplug.graphics;
import dplug.graphics.resizer;
import std.algorithm.comparison;

class UIPonko(string[] frames) : UIElement {
nothrow:
@nogc:
private:
    OwnedImage!RGBA[frames.length] _diffuseImages;
    OwnedImage!RGBA[frames.length] _diffuseImagesResized;

    size_t frame;

public:

    @ScriptProperty float animScrub = 0f;
    @ScriptProperty ubyte defaultEmissive = 0; // emissive where the logo isn't

    // these are offset on top of defaultEmissive
    @ScriptProperty ubyte emissiveOn = 40;
    @ScriptProperty ubyte emissiveOff = 0;
    
    /// Note: once called, the logo now own the diffuse image, and will destroy it.
    this(UIContext context)
    {
        super(context, flagAnimated | flagPBR);

        static foreach(i; 0..frames.length) {
            _diffuseImages[i] = loadOwnedImage(import(frames[i]));
            _diffuseImagesResized[i] = mallocNew!(OwnedImage!RGBA);
        }
    }

    ~this()
    {
        static foreach(i; 0..frames.length) {
            if (_diffuseImages[i] !is null)
            {
                destroyFree(_diffuseImages[i]);
                _diffuseImages[i] = null;
            }

            if (_diffuseImagesResized[i] !is null)
            {
                destroyFree(_diffuseImagesResized[i]);
                _diffuseImagesResized[i] = null;
            }
        }
    }

    override void reflow()
    {
        ImageResizer* resizer = context.globalImageResizer;
        static foreach(i; 0..frames.length) {
            _diffuseImagesResized[i].size(position.width, position.height);
            resizer.resizeImageDiffuse(_diffuseImages[i].toRef(), _diffuseImagesResized[i].toRef());
        }
    }

    override void onAnimate(double dt, double time) nothrow @nogc
    {
        animScrub = clamp(animScrub, 0, 1);
        float lframe = frame;
        float nframe = clamp(floor(cast(float)frames.length*animScrub), 0, frames.length-1);
        frame = cast(size_t)nframe;

        if (lframe != frame) {
            setDirtyWhole();
        }
    }

    override void onDrawPBR(ImageRef!RGBA diffuseMap, ImageRef!L16 depthMap, ImageRef!RGBA materialMap, box2i[] dirtyRects) nothrow @nogc
    {
        foreach(dirtyRect; dirtyRects)
        {
            ImageRef!RGBA croppedDiffuseIn = _diffuseImagesResized[frame].toRef().cropImageRef(dirtyRect);
            ImageRef!RGBA croppedDiffuseOut = diffuseMap.cropImageRef(dirtyRect);

            int w = dirtyRect.width;
            int h = dirtyRect.height;

            ubyte emissive = 0; //cast(ubyte)(0.5f + lerp!float(emissiveOff, emissiveOn, animScrub));

            for(int j = 0; j < h; ++j)
            {
                RGBA[] input = croppedDiffuseIn.scanline(j);
                RGBA[] output = croppedDiffuseOut.scanline(j);

                for(int i = 0; i < w; ++i)
                {
                    ubyte alpha = input[i].a;
                    RGBA color = blendColor(input[i], output[i], alpha);

                    // emissive has to be multiplied by alpha, and added to the default background emissive
                    color.a = cast(ubyte)( (128 + defaultEmissive * 256 + (emissive * color.a) ) >> 8);
                    output[i] = color;
                }
            }
        }
    }
}
