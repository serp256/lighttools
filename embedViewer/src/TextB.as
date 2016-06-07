package {
	import flash.system.System;

	import flashx.textLayout.events.SelectionEvent;

	import ui.vbase.VText;

	public class TextB extends VText {

		public function TextB(text:String = null, mode:uint = 0, color:uint = 0x1000000, fontSize:uint = 0) {
			super(text, mode, color, fontSize);
			if ((mode & SELECTION) != 0) {
				textFlow.addEventListener(SelectionEvent.SELECTION_CHANGE, onSelect);
			}
		}

		override public function dispose():void {
			textFlow.removeEventListener(SelectionEvent.SELECTION_CHANGE, onSelect);
			super.dispose();
		}

		private function onSelect(event:SelectionEvent):void {
			var str:String = textFlow.getText(event.selectionState.absoluteStart, event.selectionState.absoluteEnd);
			if (str && str.length > 3) {
				System.setClipboard(str);
			}
		}

	} //end class
}