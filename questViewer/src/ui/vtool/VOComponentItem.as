package ui.vtool {
	
	public class VOComponentItem {
		public static const
			DIGIT:uint = 1,
			TEXT:uint = 2,
			BUTTON:uint = 4,
			INFO:uint = 8,
			CHECKBOX:uint = 2048;
		
		public var key:String;
		public var mode:uint;
		public var checkbox:Boolean;
		public var value:Object;
		public var bit:uint;
		
		public function VOComponentItem(key:String, mode:uint, value:Object, checkbox:Boolean = false, bit:uint = 0):void {
			this.key = key;
			this.mode = mode;
			this.value = value;
			this.checkbox = checkbox;
			this.bit = bit;
		}
		
	} //end class
}