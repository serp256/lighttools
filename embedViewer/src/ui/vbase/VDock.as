package ui.vbase {

	public class VDock extends VComponent {

		public function VDock(mode:uint = 0) {
			this.mode = mode;
		}

		override protected function syncChildLayout(component:VComponent):void {
			syncContentSize(true);
		}

		override protected function customUpdate():void {
			super.customUpdate();

			if (!validContentSize) {
				calcContentSize();
				validContentSize = true;
			}
			var cw:Number = contentW;
			var ch:Number = contentH;
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
				if ((mode & VSkin.RIGHT) != 0) {
					dx = w - cw;
				} else if ((mode & VSkin.LEFT) == 0) {
					dx = (w - cw) / 2;
				}
				if ((mode & VSkin.BOTTOM) != 0) {
					dy = h - ch;
				} else if ((mode & VSkin.TOP) == 0) {
					dy = (h - ch) / 2;
				}
			}

			for (var i:int = numChildren - 1; i >= 0; i--) {
				var component:VComponent = getChildAt(i) as VComponent;
				if (component) {
					component.scaleX = scale;
					component.scaleY = scale;
					if (component.left != EMPTY || component.right != EMPTY || component.hCenter != EMPTY) {
						component.x += dx;
					} else {
						component.x = dx;
					}
					if (component.top != EMPTY || component.bottom != EMPTY || component.vCenter != EMPTY) {
						component.y += dy;
					} else {
						component.y = dy;
					}
				}
			}
		}

	} //end class
}
