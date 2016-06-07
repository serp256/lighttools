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
	public class AssetLoader {
		//CONFIG::SWF18, чтобы использовать режим imageDecodingPolicy = ImageDecodingPolicy.ON_LOAD
		public static var
			imageContext:LoaderContext,
			policyImageContext:LoaderContext = new LoaderContext(true)
			;
		private static const instances:Dictionary = new Dictionary();
		public var
			loader:Loader,
			packName:String,
			isError:Boolean
			;
		private var
			finishFunc:Function,
			progressHandler:Function
			;

		public static function load(urlOrBinary:Object, isSWF:Boolean, finishFunc:Function = null, progressHandler:Function = null):AssetLoader {
			var assetLoader:AssetLoader = new AssetLoader();
			assetLoader.init(finishFunc, progressHandler);
			if (urlOrBinary is ByteArray) {
				assetLoader.loadBytes(urlOrBinary as ByteArray, isSWF);
			} else {
				assetLoader.loadUrl(String(urlOrBinary), isSWF);
			}
			return assetLoader;
		}
		
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
			//loaderInfo.addEventListener(HTTPStatusEvent.HTTP_STATUS, onHttpStatus); //для тестов
			
			if (progressHandler != null) {
				this.progressHandler = progressHandler;
				loaderInfo.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			}
		}

		public function getLoaderContext(isSWF:Boolean, checkPolicyFile:Boolean = false):LoaderContext {
			if (isSWF) {
				//new ApplicationDomain(null) разделяет домены классов, что дает юзать одинаковые классы в рамках пака
				return new LoaderContext(false, new ApplicationDomain(null));
			}
			return checkPolicyFile ? policyImageContext : imageContext;
		}
		
		public function loadUrl(url:String, isSWF:Boolean):void {
			try {
				loader.load(new URLRequest(url), getLoaderContext(isSWF));
			} catch (error:Error) {
				onHandler(null);
			}
		}
		
		public function loadBytes(ba:ByteArray, isSWF:Boolean):void {
			try {
				loader.loadBytes(ba, getLoaderContext(isSWF));
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

		/*
		public function loadBytesEx(ba:ByteArray, context:LoaderContext):void {
			try {
				loader.loadBytes(ba, context);
			}  catch (error:Error) {
				onHandler(null);
			}
		}
		*/
		
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