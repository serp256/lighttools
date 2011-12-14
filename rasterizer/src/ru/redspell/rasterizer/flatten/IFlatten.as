package ru.redspell.rasterizer.flatten {
	import flash.display.DisplayObject;

	public interface IFlatten {
		function fromDisplayObject(obj:DisplayObject):IFlatten;
	}
}