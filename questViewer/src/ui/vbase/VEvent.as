package ui.vbase {
	import flash.events.Event;
	
	public class VEvent extends Event {
		public static const
			SCROLL:String = 'vScroll',
			SELECT:String = 'vSelect',
			CLOSE_DIALOG:String = 'vCloseDialog',
			CHANGE:String = 'vChange',
			VARIANCE:String = 'vVariance',
			EXTERN_COMPLETE:String = 'vExternComplete',
			SHOW_DIALOG:String = 'vShowDialog', // рассылается после открытия диалога
			GRID_INDEX:String = 'vChangeGrid';
		
		public var variance:uint;
		public var data:*;
		
		public function VEvent(type:String, data:* = null, bubbles:Boolean = false):void {
			super(type, bubbles);
			this.data = data;
		}
	} //end class
}