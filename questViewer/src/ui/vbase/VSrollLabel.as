package ui.vbase {
	import flashx.textLayout.container.ScrollPolicy;
	import flashx.textLayout.edit.SelectionManager;
	
	public class VSrollLabel extends VLabel {
		private var scrollBar:VScrollBar;
		private var isSelection:Boolean;
		
		public function VSrollLabel(scrollBar:VScrollBar, text:String = null, isSelection:Boolean = false, middleVerticalAlign:Boolean = false):void {
			this.scrollBar = scrollBar;
			this.isSelection = isSelection;
			if (scrollBar) {
				scrollBar.addListener(VEvent.SCROLL, onScrollHandler);
			}
			super(text, middleVerticalAlign ? VLabel.VERTICAL_MIDDLE : 0);
			if (isSelection) {
				mouseChildren = true;
			}
		}
		
		override public function set text(value:String):void {
			super.text = value;
			if (textFlow && isSelection) {
				textFlow.interactionManager = new SelectionManager();
			}
		}
		
		override protected function buildText(compositionWidth:Number, compositionHeight:Number):void {
			super.buildText(compositionWidth, compositionHeight);
			if (textFlow) {
				textFlow.flowComposer.getControllerAt(0).verticalScrollPolicy = ScrollPolicy.ON;
			}
			updateScroll();
		}
		
		public function updateScroll():void {
			if (scrollBar && textFlow) {
				if (textFlow) {
					var v:int = textFlow.flowComposer.getControllerAt(0).getScrollDelta(textFlow.flowComposer.numLines);
					if (v < 0) {
						v = 0;
					}
				}
				scrollBar.setProperties(h, h + v, scrollBar.scrollPosition, 0, 18)
			}
		}
		
		private function onScrollHandler(event:VEvent):void {
			if (textFlow) {
				textFlow.flowComposer.getControllerAt(0).verticalScrollPosition = event.data;
				textFlow.flowComposer.updateToController(0); 
			}
		}
		
		override protected function customUpdate():void {
			super.customUpdate();
			updateScroll();
		}
		
	} //end class
}