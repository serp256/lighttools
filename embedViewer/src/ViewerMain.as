package {
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.filesystem.File;

	import ui.vbase.VComponent;
	import ui.vtool.VToolPanel;
	

	public class ViewerMain extends Sprite {
		public static var instance:ViewerMain;
		private var panel:VComponent;

		public function ViewerMain() {
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.tabChildren = stage.stageFocusRect = false;
			instance = this;
			stage.addEventListener(Event.RESIZE, onResize);
			VToolPanel.assign(stage);
			showPath();
		}

		private function onResize(event:Event):void {
			if (panel) {
				panel.setGeometrySize(stage.stageWidth, stage.stageHeight, true);
			}
		}

		public function showPath():void {
			assignPanel(new PathPanel());
		}

		public function showViewer(file:File):void {
			var panel:ViewerPanel = new ViewerPanel();
			assignPanel(panel);
			panel.init(file);
		}

		private function assignPanel(value:VComponent):void {
			if (panel) {
				removeChild(instance.panel);
				panel.dispose();
				panel = null;
			}
			value.stretch();
			addChild(value);
			panel = value;
			onResize(null);
		}

	} //end class
}