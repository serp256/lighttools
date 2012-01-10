package ru.redspell.rasterizer.models {
	import mx.collections.ArrayCollection;

	public class SwfsPack extends ArrayCollection {
		public var name:String;
		public var proj:Project;
		public var checked:Boolean;

		public function addSwf(swf:Swf):void {
			swf.pack = this;
			addItem(swf);
		}

		public function removeSwf(swf:Swf):void {
			var index:int = getItemIndex(swf);

			if (index > -1) {
				removeItemAt(index);
				swf.pack = null;
			}
		}

		public function get swfs():Array {
			return source;
		}
	}
}