package ru.redspell.rasterizer.flatten {
	import com.codeazur.as3swf.tags.IDefinitionTag;
	import flash.display.DisplayObject;
	import ru.redspell.rasterizer.models.SwfClass;

	public interface IFlatten {
		function fromSwfClass(cls:SwfClass, scale:Number):IFlatten;
		function fromDisplayObject(obj:DisplayObject, scale:Number = 1, tag:IDefinitionTag = null):IFlatten;
		function render():void;
		function dispose():void;
	}
}