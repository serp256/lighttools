package ru.redspell.rasterizer.models {
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.File;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;

	import mx.collections.ArrayCollection;

	import ru.etcs.utils.getDefinitionNames;

	public class Swf extends ArrayCollection {
		public var path:String;
		public var checked:Boolean;
		public var animated:Boolean;
		public var pack:SwfsPack;
		protected var _useGetDefinitions:Boolean;

		public function addClass(cls:SwfClass):void {
			addItem(cls);
			cls.swf = this;
		}

		public function removeClass(cls:SwfClass):void {
			var index:int = getItemIndex(cls);

			if (index > -1) {
				removeItemAt(index);
				cls.swf = null;
			}
		}

		protected function loader_completeHandler(event:Event):void {
			var li:LoaderInfo = event.target as LoaderInfo;
			var appDomain:ApplicationDomain = li.applicationDomain;
			var classes:Array = _useGetDefinitions ? getDefinitionNames(li) : source;

			for each (var cls:Object in classes) {
				if (cls is SwfClass) {
					(cls as SwfClass).definition = appDomain.getDefinition(cls.name) as Class;
				} else {
					var className:String = String(cls);
					addClass(Facade.projFactory.getSwfClass(appDomain.getDefinition(className) as Class, className));
				}
			}

			dispatchEvent(new Event(Event.COMPLETE));
		}

		protected function loader_ioErrorHandler(event:IOErrorEvent):void {
		}

		public function loadClasses(swfsDir:File, useGetDefinitions:Boolean = true):void {
			var loader:Loader = new Loader();

			_useGetDefinitions = useGetDefinitions;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loader_completeHandler);

			loader.addEventListener(IOErrorEvent.IO_ERROR, loader_ioErrorHandler);
			loader.load(new URLRequest(swfsDir.resolvePath(path).url));
		}

		public function get classes():Array {
			return source;
		}
	}
}