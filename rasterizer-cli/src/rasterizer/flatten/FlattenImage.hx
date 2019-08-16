package rasterizer.flatten;

import format.swf.tags.IDefinitionTag;
import flash.display.BitmapData;
import flash.display.DisplayObject;
import flash.geom.Matrix;
import rasterizer.model.SWFClass;

import openfl.filters.GlowFilter;
import openfl.filters.BlurFilter;
import openfl.filters.BitmapFilter;

import openfl.geom.Rectangle;


class FlattenImage extends BitmapData implements IFlatten {
	
	public var name = "";
	public var matrix = new Matrix();
	public var mask : String = null;

	/*
	 *
	 */
	public function new(width : Int, height : Int, transparent : Bool = true, fillColor:UInt = 0xFFFFFFFF) {
		super(width, height, transparent, fillColor);
	}
	
	/*
	 *
	 */
	public function fromSwfClass(cls : SWFClass, scale : Float) : IFlatten {
		return fromDisplayObject(cls.createInstance(), scale);
	}
	
	/*
	 *
	 */
	public function fromDisplayObject(obj : DisplayObject, scale : Float = 1.0, tag : IDefinitionTag = null) : IFlatten {
		draw(obj, new Matrix(scale, 0, 0, scale));
		return this;
	}

	/*
	 *
	 */
	public override function generateFilterRect(sourceRect:Rectangle, filter:BitmapFilter):Rectangle {
		if (Std.is(filter, GlowFilter)) {
			var f : GlowFilter = cast filter;			
			var rect = sourceRect.clone();

			if (f.inner) {								
				// вообще глоу внтурнеиий не работает
				// trace('INNER RECT $sourceRect => $rect (bx = ${f.blurX} by = ${f.blurY})');		
				// Бывает так, что внутренний блюр больше ширины или высоты, тогда растеризатор выдает segfault
				f.blurX = Math.min(f.blurX, rect.width);
				f.blurY = Math.min(f.blurY, rect.height);
			} else {								
				rect.inflate(f.blurX / 2, f.blurY / 2);
				// trace('INFLATED SOURCE RECT $sourceRect => $rect (bx = ${f.blurX} by = ${f.blurY})');
			}

			return rect;
		}
		
		if (Std.is(filter, rasterizer.InnerGlowFilter)) {
			var rect = sourceRect.clone();
			var f : rasterizer.InnerGlowFilter = cast filter;		
			f.blurX = Math.min(f.blurX, rect.width);
			f.blurY = Math.min(f.blurY, rect.height);
			return rect;
		}

		if (Std.is(filter, BlurFilter)) {
			var f : BlurFilter = cast filter;			
			var rect = sourceRect.clone();			
			rect.inflate(f.blurX / 2, f.blurY / 2);
			return rect;
		}

		return super.generateFilterRect(sourceRect, filter);
	}
	

	public function render() : Void {}
}
