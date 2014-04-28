package ui.vbase {
	import flash.events.EventDispatcher;
	
	public class VOListener {
		public var dispatcher:EventDispatcher;
		public var type:String;
		public var handler:Function;
		public var useCapture:Boolean;
		
	} //end class
}