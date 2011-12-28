package ru.redspell.rasterizer.export {
	public interface IExporter {
		function export(obj:Object, className:String):IExporter;
		function setPath(path:Object):IExporter;
	}
}