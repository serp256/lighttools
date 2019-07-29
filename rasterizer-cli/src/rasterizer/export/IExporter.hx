package rasterizer.export;

import rasterizer.flatten.IFlatten;


interface IExporter {
	function export(obj : IFlatten, className : String) : IExporter;
	function setPath(path : haxe.io.Path) : IExporter;
}