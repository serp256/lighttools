package ru.redspell.rasterizer.flatten {
	import flash.display.DisplayObject;

	public interface IFlatten {
		function fromDisplayObject(obj:DisplayObject, scale:Number = 1):IFlatten;
		function render():void;
		function dispose():void;
	}
}