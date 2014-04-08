package ui.vbase {
	import flash.display.DisplayObject;

	public class VDock extends VBaseComponent {
		private var mode:uint;

		public function VDock(mode:uint = 0):void {
			this.mode = mode;
		}

		override protected function customUpdate():void {
			updateAllChild();

			var cw:Number = contentWidth;
			var ch:Number = contentHeight;
			var scale:Number = 1;
			var dx:int;
			var dy:int;

			if (w > 0 && h > 0 && cw > 0 && ch > 0) {
				if ((mode & VSkin.CONTAIN) != 0 && cw <= w && ch <= h) {
					return;
				}
				if (w / h <= cw / ch) {
					scale = w / cw;
				} else {
					scale = h / ch;
				}

				cw *= scale;
				ch *= scale;
				if (mode & VSkin.RIGHT) {
					dx = w - cw;
				} else if ((mode & VSkin.LEFT) == 0) {
					dx = (w - cw) / 2;
				}
				if (mode & VSkin.BOTTOM) {
					dy = h - ch;
				} else if ((mode & VSkin.TOP) == 0) {
					dy = (h - ch) / 2;
				}
			}

			for (var i:int = numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = getChildAt(i);
				if (obj is VBaseComponent) {
					obj.scaleX = scale;
					obj.scaleY = scale;
					obj.x += dx;
					obj.y += dy;
				}
			}
		}

	} //end class
}
