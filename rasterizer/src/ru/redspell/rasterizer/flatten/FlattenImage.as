package ru.redspell.rasterizer.flatten {
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.geom.Matrix;

	public class FlattenImage extends BitmapData implements IFlatten {
		public var name:String = '';
		public var matrix:Matrix = new Matrix();

		public function FlattenImage(width:int, height:int, transparent:Boolean = true, fillColor:uint = 0xFFFFFFFF) {
			super(width, height, transparent, fillColor);
		}

		public function fromDisplayObject(obj:DisplayObject):IFlatten {
			draw(obj);
			return this;
		}

		public function render():void {
		}
	}
}