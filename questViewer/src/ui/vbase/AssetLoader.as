package ui.vbase {
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	/**
	 * Вспомогательный объект для загрузки графики
	 * Устанавливает слушатели для Loader, и при завершении вызвывает функцию завершения
	 */
	final public class AssetLoader {
		private static var instances:Dictionary = new Dictionary();
		
		public var loader:Loader;
		public var packName:String;
		public var isError:Boolean;
		
		private var finishFunc:Function;
		private var progressHandler:Function;
		
		/**
		 * Иницилизация загрузчика
		 * 
		 * @param	finishFunc
		 * @param	progressHandler
		 * @return
		 */
		public function init(finishFunc:Function = null, progressHandler:Function = null):void {
			instances[this] = true;
			this.finishFunc = finishFunc;
			
			loader = new Loader();
			var loaderInfo:LoaderInfo = loader.contentLoaderInfo;
			loaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onHandler);
			loaderInfo.addEventListener(Event.COMPLETE, onHandler);
			//loaderInfo.addEventListener(HTTPStatusEvent.HTTP_STATUS, onHttpStatusHandler); //для тестов
			
			if (progressHandler != null) {
				this.progressHandler = progressHandler;
				loaderInfo.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			}
		}
		
		public function loadUrl(url:String, isSWF:Boolean):void {
			try {
				loader.load(
					new URLRequest(url),
					//new ApplicationDomain(null) разделяет домены классов, что дает юзать одинаковые классы в рамках пака
					isSWF ? new LoaderContext(false, new ApplicationDomain(null)) : null
				);
			} catch (error:Error) {
				onHandler(null);
			}
		}
		
		public function loadBytes(ba:ByteArray, isSWF:Boolean):void {
			try {
				loader.loadBytes(ba, isSWF ? new LoaderContext(false, new ApplicationDomain(null)) : null);
			}  catch (error:Error) {
				onHandler(null);
			}
		}
		
		public function loadEx(url:String, context:LoaderContext):void {
			try {
				loader.load(new URLRequest(url), context);
			} catch (error:Error) {
				onHandler(null);
			}
		}
		
		public function loadBytesEx(ba:ByteArray, context:LoaderContext):void {
			try {
				loader.loadBytes(ba, context);
			}  catch (error:Error) {
				onHandler(null);
			}
		}
		
		private function onHandler(event:Event):void {
			isError = (!event || event.type != Event.COMPLETE);

			var loaderInfo:LoaderInfo = loader.contentLoaderInfo;
			loaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onHandler);
			loaderInfo.removeEventListener(Event.COMPLETE, onHandler);
			if (progressHandler != null) {
				loaderInfo.removeEventListener(ProgressEvent.PROGRESS, progressHandler);
				progressHandler = null;
			}
			
			delete instances[this];
			if (finishFunc != null) {
				finishFunc(this);
			}
			finishFunc = null;
			loader = null;
		}

		public function reset():void {
			if (loader) {
				finishFunc = null;
				try {
					loader.close();
				} catch (error:Error) {
				}
				if (loader) {
					onHandler(null);
				}
			}
		}
		
	} //end class
}