package ru.redspell.rasterizer.models {
	import mx.collections.ArrayCollection;

	public class Project extends ArrayCollection {
		protected var _lastAdded:SwfsPack;

		public function addPack(pack:SwfsPack):void {
			addItem(pack);
			pack.proj = this;
			_lastAdded = pack;
		}

		public function removePack(pack:SwfsPack):void {
			var index:int = getItemIndex(pack);

			if (index > - 1) {
				pack.proj = null;
				removeItemAt(index);
			}
		}

		public function get packs():Array {
			return source;
		}

		public function get lastAdded():SwfsPack {
			return _lastAdded;
		}
	}
}