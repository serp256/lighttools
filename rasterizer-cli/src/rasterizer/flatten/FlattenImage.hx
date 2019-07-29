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
			rect.inflate(f.blurX, f.blurY);
			return rect;
		}


		if (Std.is(filter, BlurFilter)) {
			var f : BlurFilter = cast filter;
			var rect = sourceRect.clone();
			rect.inflate(f.blurX, f.blurY);
			return rect;
		}

		return super.generateFilterRect(sourceRect, filter);
	}
	

	public function render() : Void {}
}
