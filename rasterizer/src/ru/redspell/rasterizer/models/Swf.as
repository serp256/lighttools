package ru.redspell.rasterizer.models {
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;

	import mx.collections.ArrayCollection;

	import ru.etcs.utils.getDefinitionNames;

	public class Swf extends ArrayCollection {
		public var path:String;
		public var checked:Boolean = true;
		public var pack:SwfsPack;
		protected var _useGetDefinitions:Boolean;

		public function addClass(cls:SwfClass):void {
			addItem(cls);
		}

		public function removeClass(cls:SwfClass):void {
			var index:int = getItemIndex(cls);

			if (index > -1) {
				removeItemAt(index);
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
					addItem(Facade.projFactory.getSwfClass(appDomain.getDefinition(className) as Class, className));
				}
			}
		}

		public function loadClasses(useGetDefinitions:Boolean = true):void {
			var loader:Loader = new Loader();

			_useGetDefinitions = useGetDefinitions;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loader_completeHandler)
			loader.load(new URLRequest((new File(path)).url));
		}

		public function get classes():Array {
			return source;
		}

		public function get name():String {
			return (new File(path)).name;
		}
	}
}