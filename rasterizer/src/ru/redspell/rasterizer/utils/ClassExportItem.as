package ru.redspell.rasterizer.utils {
	import flash.display.DisplayObject;

	public class ClassExportItem {
		public var swfName:String;
		public var className:String;
		public var src:DisplayObject;

		public function ClassExportItem(swfName:String, className:String, src:DisplayObject) {
			this.swfName = swfName;
			this.className = className;
			this.src = src
		}
	}
}