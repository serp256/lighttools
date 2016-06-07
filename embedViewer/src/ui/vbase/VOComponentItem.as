package ui.vbase {
	
	public class VOComponentItem {
		public static const
			DIGIT:uint = 1,
			TEXT:uint = 2,
			BUTTON:uint = 4,
			INFO:uint = 8,
			SPEC:uint = 16,
			CHECKBOX:uint = 2048
			;
		
		public var
			key:String,
			mode:uint,
			checkbox:Boolean,
			value:Object,
			bit:uint
			;
		
		public function VOComponentItem(key:String, mode:uint, value:Object, checkbox:Boolean = false, bit:uint = 0) {
			this.key = key;
			this.mode = mode;
			this.value = value;
			this.checkbox = checkbox;
			this.bit = bit;
		}

		public function getInt(min:int = 0, max:int = int.MAX_VALUE):int {
			var i:int;
			if (value is String || value is Number) {
				var n:Number = Number(value);
				if (!isNaN(n)) {
					i = n;
				}
			} else {
				i = int(value);
			}
			if (i < min) {
				return min;
			} else if (i > max) {
				return max;
			}
			return i;
		}

		public function get valueInt():int {
			return getInt();
		}

		public function get valueString():String {
			return String(value);
		}
		
	} //end class
}