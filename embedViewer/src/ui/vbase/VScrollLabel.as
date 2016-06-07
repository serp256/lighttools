package ui.vbase {
	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.container.ScrollPolicy;
	import flashx.textLayout.edit.SelectionManager;
	import flashx.textLayout.elements.TextFlow;

	public class VScrollLabel extends VLabel {
		public static const
			SELECTION_MODE:uint = 2048,
			USE_MANUAL_SCROLL:uint = 4096,
			USE_BAR_VISIBLE:uint = 8192
			;
		private var
			scrollBar:VScrollBar,
			minShift:uint
			;
		
		public function VScrollLabel(scrollBar:VScrollBar, text:String = null, mode:uint = 0, minShift:uint = 18) {
			this.scrollBar = scrollBar;
			this.minShift = minShift;
			scrollBar.addListener(VEvent.SCROLL, setScroll);
			super(text, mode);
			if ((mode & SELECTION_MODE) != 0) {
				mouseChildren = true;
			}
		}

		public function getTextFlow():TextFlow {
			return textFlow;
		}
		
		override public function set text(value:String):void {
			super.text = value;
			if (textFlow) {
				if ((mode & SELECTION_MODE) != 0) {
					textFlow.interactionManager = new SelectionManager();
				}
			}
		}

		override protected function buildText(compositionWidth:Number, compositionHeight:Number):void {
			super.buildText(compositionWidth, compositionHeight);
			if (textFlow) {
				textFlow.flowComposer.getControllerAt(0).verticalScrollPolicy = ScrollPolicy.ON;
			}
			updateScroll();
		}

		public function getScrollHeight():Number {
			var textHeight:Number = 0;
			if (textFlow && isGeometryPhase) {
				var cc:ContainerController = textFlow.flowComposer.getControllerAt(0);
				if (cc) {
					textFlow.flowComposer.composeToPosition();
					textHeight = cc.getScrollDelta(textFlow.flowComposer.numLines);
					if (textHeight < 0) {
						textHeight = 0;
					}
				}
			}
			return textHeight;
		}
		
		private function updateScroll():void {
			if ((mode & USE_MANUAL_SCROLL) == 0) {
				var max:uint = h + getScrollHeight();
				scrollBar.setEnv(h, max, scrollBar.value, minShift);
				if ((mode & USE_BAR_VISIBLE) != 0) {
					scrollBar.visible = h < max;
				}
			}
		}

		//data - VEvent || Number
		public function setScroll(data:Object):void {
			if (textFlow && textFlow.flowComposer.numControllers > 0) {
				textFlow.flowComposer.getControllerAt(0).verticalScrollPosition = (data is VEvent) ? (data as VEvent).data : Number(data);
				textFlow.flowComposer.updateToController(0);
			}
		}

		public function getScrollBar():VScrollBar {
			return scrollBar;
		}

	} //end class
}