package ru.redspell.rasterizer.flatten {
	import com.codeazur.as3swf.tags.IDefinitionTag;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.geom.Matrix;
	import ru.redspell.rasterizer.models.SwfClass;

	public class FlattenImage extends BitmapData implements IFlatten {
		public var name:String = '';
		public var matrix:Matrix = new Matrix();

		public function FlattenImage(width:int, height:int, transparent:Boolean = true, fillColor:uint = 0xFFFFFFFF) {
			super(width, height, transparent, fillColor);
		}
		
		public function fromSwfClass(cls:SwfClass, scale:Number):IFlatten {
			draw(new cls.definition(), new Matrix(scale, 0, 0, scale));
			return this;
		}

		public function fromDisplayObject(obj:DisplayObject, scale:Number = 1, tag:IDefinitionTag = null):IFlatten {
			draw(obj, new Matrix(scale, 0, 0, scale));
			return this;
		}

		public function render():void {
		}
	}
}