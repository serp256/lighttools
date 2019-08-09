package rasterizer;

import openfl.filters.BitmapFilter;
import openfl.display.BitmapData;
import openfl.display.BitmapDataChannel;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.geom.ColorTransform;
import lime._internal.graphics.ImageDataUtil;

/*
 * Реализация inner glow. knockout не поддерживается
 */

@:access(openfl.geom.Rectangle)
@:access(openfl.geom.Point)
@:access(openfl.geom.ColorTransform)
class InnerGlowFilter extends BitmapFilter {
    
    public var alpha(get, set):Float;

	public var blurX(get, set):Float;

	public var blurY(get, set):Float;

	public var color(get, set):Int;

	public var quality(get, set):Int;

	public var strength(get, set):Float;

    private var __alpha:Float;
    private var __blurX:Float;
    private var __blurY:Float;
    private var __color:Int;
    private var __horizontalPasses:Int;
    private var __quality:Int;
    private var __strength:Float;
    private var __verticalPasses:Int;


    public function new(color:Int = 0xFF0000, alpha:Float = 1, blurX:Float = 6, blurY:Float = 6, strength:Float = 2, quality:Int = 1) {
		super();

		__color = color;
		__alpha = alpha;
        __strength = strength;
		
        this.blurX = blurX;
		this.blurY = blurY;		
		this.quality = quality;

		__needSecondBitmapData = true;
		__preserveObject = false;
		__renderDirty = true;
	}


    /*
     *
     */
	public override function clone():BitmapFilter {
		return new InnerGlowFilter(__color, __alpha, __blurX, __blurY, __strength, __quality);
	}

	
    /*
     *
     */
    private override function __applyFilter(bitmapData:BitmapData, sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point) : BitmapData {
		#if lime
		bitmapData.copyPixels(sourceBitmapData, new Rectangle(0, 0, sourceBitmapData.width, sourceBitmapData.height), new Point(0, 0));
        
		//
        // делаем ЧБ изображение-маску. Там где bitmapData имеет непрозрачные пиксели, там наша маска черная
		// 
		//
        var alphaImage = new BitmapData(Math.ceil(bitmapData.width + __blurX), Math.ceil(bitmapData.height + __blurY), 0xFFFFFFFF);        
        var alphaImageRect = new Rectangle(0, 0, alphaImage.width, alphaImage.height);
        var zeroPoint = new Point(0, 0);

        alphaImage.threshold(sourceBitmapData, new Rectangle(0, 0, sourceBitmapData.width, sourceBitmapData.height), new Point(Math.floor(__blurX / 2), Math.floor(__blurX / 2)), "==", 0xFF000000, 0xFF000000, 0xFF000000, false);

        
		//
		// делаем размытую копию нашей маски. размытие будет как изнутри, так и снаружи. Потом применим четкую маску, чтобы убрать наружнее размытие и оставить только внутреннее
		// используем две копии изображения, так как так надо :D такая внутренняя lime реализация
		//
        var blur_1= new BitmapData(alphaImage.width, alphaImage.height, 0xFFFFFFFF);
		var blur_2= new BitmapData(alphaImage.width, alphaImage.height, 0xFFFFFFFF);

        blur_1.copyPixels(alphaImage, alphaImageRect, zeroPoint);                
		blur_2.copyPixels(alphaImage, alphaImageRect, zeroPoint);                

        ImageDataUtil.gaussianBlur(blur_1.image, blur_2.image, alphaImageRect.__toLimeRectangle(), zeroPoint.__toLimeVector2(), __blurX, __blurY, __quality, /* __strength */1.0);

        // то, что в маске белое надо заменить на черный цвет
        // наверное если сделать изначально инвертированные изображения, то жтого шага можно избежать
        blur_1.threshold(alphaImage, alphaImageRect, zeroPoint, "==", 0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, false);
        
        // теперь любой цветовой канал у нас это альфаканал (где черный цвет - полная прозрачность (a=0))
        // копируем его в реальный альфа канал, чтобы получить правильную херню
        // а чтобы поменять цвет, применяем цветовую трансформацию.
        blur_1.copyChannel(blur_1, alphaImageRect, zeroPoint, BitmapDataChannel.RED, BitmapDataChannel.ALPHA);
        
        var ct = new ColorTransform(0, 0, 0, __alpha * __strength);
        ct.color = __color;   

		blur_1.colorTransform(alphaImageRect, ct);	        
        bitmapData.draw(blur_1, new Matrix(1, 0, 0, 1, - Math.floor(__blurX / 2), - Math.floor(__blurY / 2)), null, null, new Rectangle(0, 0, bitmapData.width, bitmapData.height), true);		
		return bitmapData;
		#end
		return sourceBitmapData;
	}




	
	// Get & Set Methods
	private function get_alpha() : Float {
		return __alpha;
	}

	private function set_alpha(value:Float) : Float {
		if (value != __alpha) __renderDirty = true;
		return __alpha = value;
	}

	private function get_blurX():Float
	{
		return __blurX;
	}

	@:noCompletion private function set_blurX(value:Float) : Float {
		if (value != __blurX)
		{
			__blurX = value;
			__renderDirty = true;
			__leftExtension = (value > 0 ? Math.ceil(value * 1.5) : 0);
			__rightExtension = __leftExtension;
		}
		return value;
	}

	@:noCompletion private function get_blurY():Float
	{
		return __blurY;
	}

	@:noCompletion private function set_blurY(value:Float):Float
	{
		if (value != __blurY)
		{
			__blurY = value;
			__renderDirty = true;
			__topExtension = (value > 0 ? Math.ceil(value * 1.5) : 0);
			__bottomExtension = __topExtension;
		}
		return value;
	}

	@:noCompletion private function get_color():Int
	{
		return __color;
	}

	@:noCompletion private function set_color(value:Int):Int
	{
		if (value != __color) __renderDirty = true;
		return __color = value;
	}

	@:noCompletion private function get_quality():Int
	{
		return __quality;
	}

	@:noCompletion private function set_quality(value:Int) : Int	{
		__horizontalPasses = (__blurX <= 0) ? 0 : Math.round(__blurX * (value / 4)) + 1;
		__verticalPasses = (__blurY <= 0) ? 0 : Math.round(__blurY * (value / 4)) + 1;

		__numShaderPasses = __horizontalPasses + __verticalPasses;

		if (value != __quality) __renderDirty = true;
		return __quality = value;
	}

	@:noCompletion private function get_strength():Float {
		return __strength;
	}

	@:noCompletion private function set_strength(value:Float):Float
	{
		if (value != __strength) __renderDirty = true;
		return __strength = value;
	}

}