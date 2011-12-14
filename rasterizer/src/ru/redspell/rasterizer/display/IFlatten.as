package ru.redspell.rasterizer.display {
	import flash.display.DisplayObject;

	public interface IFlatten {
		function fromDisplayObject(obj:DisplayObject):IFlatten;
	}
}