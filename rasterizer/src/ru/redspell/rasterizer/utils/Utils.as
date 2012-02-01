package ru.redspell.rasterizer.utils {
	import flash.display.DisplayObjectContainer;

	public class Utils {
		public static function traceObj(obj:DisplayObjectContainer, indentSize:uint = 0):void {
			var indent:String = '';

			while (indent.length < indentSize) { indent += '\t'; }

			for (var i:uint = 0; i < obj.numChildren; i++) {
				var child:* = obj.getChildAt(i);

				if (child) {
					trace(indent + child + ' ' + (child.hasOwnProperty('name') ? child.name : 'noname'));

					if (child is DisplayObjectContainer) {
						traceObj(child as DisplayObjectContainer, indentSize + 1);
					}
				} else {
					trace('child is null');
				}
			}
		}
	}
}