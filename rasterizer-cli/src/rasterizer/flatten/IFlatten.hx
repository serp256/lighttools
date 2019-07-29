package rasterizer.flatten;

import flash.display.DisplayObject;
import format.swf.tags.IDefinitionTag;
import rasterizer.model.SWFClass;


interface IFlatten {
	function fromSwfClass(cls : SWFClass, scale : Float) : IFlatten;
	function fromDisplayObject(obj : DisplayObject, scale : Float = 1.0, tag:IDefinitionTag = null) : IFlatten;
	function render() : Void;
	function dispose(): Void;
}
