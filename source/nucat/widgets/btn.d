module nucat.widgets.btn;
import std.math;
import dplug.gui.element;
import dplug.core.math;
import dplug.graphics;
import dplug.graphics.resizer;
import dplug.client;
import std.algorithm.comparison;

class UIButton : UIElement, IParameterListener {
nothrow:
@nogc:
private:
    bool held = false;

    size_t frame = 0;
    BoolParameter _param;

    OwnedImage!RGBA[3] _diffuseImages;
    OwnedImage!RGBA[3] _emissiveImages;

    OwnedImage!RGBA[3] _diffuseImagesResized;
    OwnedImage!RGBA[3] _emissiveImagesResized;

    

    /// Returns: largest square centered in _position
    box2i getSubsquare() pure const nothrow @nogc {
        // We'll draw entirely in the largest centered square in _position.
        box2i subSquare;
        if (_position.width > _position.height)
        {
            int offset = (_position.width - _position.height) / 2;
            int minX = offset;
            subSquare = box2i(minX, 0, minX + _position.height, _position.height);
        }
        else
        {
            int offset = (_position.height - _position.width) / 2;
            int minY = offset;
            subSquare = box2i(0, minY, _position.width, minY + _position.width);
        }
        return subSquare;
    }

    bool containsPoint(int x, int y) nothrow @nogc {
        return getSubsquare().contains(vec2i(x, y));
    }

public:
    ~this() {
        _param.removeListener(this);
    }

    this(UIContext context, BoolParameter param) {
        super(context, flagPBR);
        _param = param;
        _param.addListener(this);

        frame = cast(size_t)(param.getNormalized()*2);

        static foreach(i; 0..3) {
            _diffuseImagesResized[i] = mallocNew!(OwnedImage!RGBA);
            _emissiveImagesResized[i] = mallocNew!(OwnedImage!RGBA);
        }

        _diffuseImages[0] = loadOwnedImage(import("tex/btn/btn_albedo1.png"));
        _diffuseImages[1] = loadOwnedImage(import("tex/btn/btn_albedo2.png"));
        _diffuseImages[2] = loadOwnedImage(import("tex/btn/btn_albedo3.png"));

        _emissiveImages[0] = loadOwnedImage(import("tex/btn/btn_emissive1.png"));
        _emissiveImages[1] = loadOwnedImage(import("tex/btn/btn_emissive2.png"));
        _emissiveImages[2] = loadOwnedImage(import("tex/btn/btn_emissive3.png"));
    }

    override
    Click onMouseClick(int x, int y, int button, bool isDoubleClick, MouseState mstate) {
        if (!containsPoint(x, y))
            return Click.unhandled;
        return Click.startDrag;
    }

    // For lazy updates
    override
    void onBeginDrag() {
        held = true;
        frame = 1;
        setDirtyWhole();
    }

    override
    void onStopDrag() {
        if (isMouseOver) {
            bool cState = !cast(bool)_param.getNormalized();
            _param.beginParamEdit();
            _param.setFromGUI(cState);
            _param.endParamEdit();

            frame = cState ? 2 : 0;
        }
        held = false;
        setDirtyWhole();
    }

    override
    void onMouseEnter() {
        _param.beginParamHover();
    }

    override
    void onMouseExit() {
        _param.endParamHover();
        setDirtyWhole();
    }

    override
    void onDrawPBR(ImageRef!RGBA diffuseMap, ImageRef!L16 depthMap, ImageRef!RGBA materialMap, box2i[] dirtyRects) nothrow @nogc {
        foreach(dirtyRect; dirtyRects) {
            ImageRef!RGBA croppedDiffuseIn = _diffuseImagesResized[frame].toRef().cropImageRef(dirtyRect);
            ImageRef!RGBA croppedEmissionIn = _emissiveImagesResized[frame].toRef().cropImageRef(dirtyRect);
            ImageRef!RGBA croppedDiffuseOut = diffuseMap.cropImageRef(dirtyRect);

            int w = dirtyRect.width;
            int h = dirtyRect.height;

            for(int j = 0; j < h; ++j)
            {
                RGBA[] input = croppedDiffuseIn.scanline(j);
                RGBA[] inputE = croppedEmissionIn.scanline(j);
                RGBA[] output = croppedDiffuseOut.scanline(j);

                for(int i = 0; i < w; ++i)
                {
                    ubyte alpha = input[i].a;
                    float emissive = cast(float)inputE[i].r/255.0f;

                    RGBA color = blendColor(input[i], output[i], alpha);
                    float a = cast(float)color.a/255.0f;
                    ubyte em = cast(ubyte)(clamp(((a*0.20) + emissive), 0, 1)*255);

                    // emissive has to be multiplied by alpha, and added to the default background emissive
                    color.a = em;
                    output[i] = color;
                }
            }
        }
    }

    override
    void reflow() {
        ImageResizer* resizer = context.globalImageResizer;
        static foreach(i; 0..3) {
            _diffuseImagesResized[i].size(position.width, position.height);
            resizer.resizeImageNearest(_diffuseImages[i].toRef(), _diffuseImagesResized[i].toRef());

            _emissiveImagesResized[i].size(position.width, position.height);
            resizer.resizeImageNearest(_emissiveImages[i].toRef(), _emissiveImagesResized[i].toRef());
        }
    }


    override
    void onParameterChanged(Parameter sender) {
        setDirtyWhole();
    }

    override
    void onBeginParameterEdit(Parameter sender) {
    }

    override
    void onEndParameterEdit(Parameter sender) {
    }

    override
    void onBeginParameterHover(Parameter sender) {
    }

    override
    void onEndParameterHover(Parameter sender) {
    }
}