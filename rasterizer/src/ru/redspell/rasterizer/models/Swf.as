package ru.redspell.rasterizer.models {
	import com.codeazur.as3swf.SWF;
	import com.codeazur.as3swf.SWFTimelineContainer;
	import com.codeazur.as3swf.data.SWFSymbol;
	import com.codeazur.as3swf.tags.IDefinitionTag;
	import com.codeazur.as3swf.tags.ITag;
	import com.codeazur.as3swf.tags.TagSymbolClass;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import mx.collections.ArrayCollection;
	import ru.etcs.utils.getDefinitionNames;
	import ru.nazarov.asmvc.command.CommandError;



	public class Swf extends ArrayCollection {
		public var path:String;
		public var animated:Boolean;
		public var pack:SwfsPack;
        public var scales:Object = {};
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
		
		public static function getSwfCharacter(swf:SWF, id:uint):IDefinitionTag {
			for each (var tag:ITag in swf.tags) {
				if (tag is IDefinitionTag && tag is SWFTimelineContainer && (tag as IDefinitionTag).characterId == id) {
					return tag as IDefinitionTag;
				}
			}
			//throw new Error('no symbol character');
			return swf.getCharacter(id);
		}

		protected function loader_completeHandler(event:Event):void {
			try {
				var li:LoaderInfo = event.target as LoaderInfo;
				li.loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, loader_completeHandler);
				li.loader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ioErrorHandler);
				var swf:SWF = new SWF(li.bytes);
				li.bytes.position = 0;
				
				var definedObjs:Object = {};
				for each (var tag:ITag in swf.tags) {
					if (tag is TagSymbolClass) {
						var symbol_tag:TagSymbolClass = tag as TagSymbolClass;
						for each (var symbol:SWFSymbol in symbol_tag.symbols) {
							definedObjs[symbol.name] = symbol.tagId;
						}
					}
				}
				
				var appDomain:ApplicationDomain = li.applicationDomain;

				if (_useGetDefinitions) {
					var classes:Array = getDefinitionNames(li);
					classes.sort();
				} else {
					classes = source;
				}
				
				for each (var cls:Object in classes) {
					var swfClass:SwfClass = null;
					if (cls is SwfClass) {
						swfClass = cls as SwfClass;
						swfClass.tag = getSwfCharacter(swf, definedObjs[swfClass.name.replace('::', '.')]);
						swfClass.root = swf;
						swfClass.definition = appDomain.getDefinition(cls.name) as Class;
					} else {
						var className:String = String(cls);
						if (/E?Skins./.test(className)) {
							swfClass = Facade.projFactory.getSwfClass(appDomain.getDefinition(className) as Class, className);
							swfClass.tag = getSwfCharacter(swf, definedObjs[className.replace('::', '.')]);
							swfClass.root = swf;
							addClass(swfClass);
						}
					}
				}
				
				dispatchEvent(new Event(Event.COMPLETE));
			} catch (e:Error) {
				Facade.app.reportError(CommandError.create(e, this.toString()));
			}
		}

		protected function loader_ioErrorHandler(event:IOErrorEvent):void {
			throw new Error('failed to load swf ' + event);
		}

		public function loadClasses(useGetDefinitions:Boolean = true):void {
			//trace('loading', path);
			var loader:Loader = new Loader();

			_useGetDefinitions = useGetDefinitions;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loader_completeHandler);

			loader.addEventListener(IOErrorEvent.IO_ERROR, loader_ioErrorHandler);
			loader.load(new URLRequest(new File(path).url));
		}

		public function get classes():Array {
			return source;
		}

		public function get filename():String {
			return new File(path).name;
		}
	}
}