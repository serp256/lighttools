package ru.redspell.rasterizer.utils {
	import flash.events.EventDispatcher;

	public class ClassesGridItemData extends EventDispatcher {
		[Bindable]
		public var export:Boolean;
		public var name:String;
		public var cls:Class;

		public function ClassesGridItemData(cls:Class, name:String, export:Boolean = true) {
			this.export = export;
			this.name = name;
			this.cls = cls;
		}
	}
}