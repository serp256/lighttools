package {
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;

	import ru.redspell.rasterizer.utils.Utils;

	public class Tester extends Sprite {
		public function Tester() {
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
			trace('______________________________________________trace start date ' + (new Date()) + '______________________________________________');
		}

		protected function addedToStageHandler(event:Event):void {
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loader_completeHandler);
			loader.load(new URLRequest('file:///Users/andrey/Desktop/UI.swf'));
		}

		protected function loader_completeHandler(event:Event):void {
			var appDomain:ApplicationDomain = (event.target as LoaderInfo).applicationDomain;
			var LoadClip:Class = appDomain.getDefinition('ESkins.LoadClip') as Class;
			var loadClip:MovieClip = new LoadClip () as MovieClip;

			var xyu:MovieClip = loadClip.getChildAt(loadClip.numChildren - 1) as MovieClip;

			for (var i:uint = 0; i < xyu.totalFrames; i++) {
				xyu.gotoAndStop(i + 1);
				var pizda:Shape = xyu.getChildAt(0) as Shape;

				trace(i, xyu, xyu.getBounds(xyu), xyu.transform.matrix);
				trace(i, pizda, pizda.getBounds(pizda), pizda.transform.matrix);

				addChild(pizda);
				break;
				//Utils.traceObj(loadClip);
			}

			//var xyu:MovieClip = loadClip.getChildAt(loadClip.numChildren - 1) as MovieClip;
			//
			//xyu.gotoAndStop(1);
			//trace(xyu.transform.matrix);
			//trace(xyu.getChildAt(0).transform.matrix);
			//
			//xyu.gotoAndStop(29);
			//trace(xyu.transform.matrix);
			//trace(xyu.getChildAt(0).transform.matrix);
			//
			//
			//addChild(xyu.getChildAt(0));
		}
	}
}