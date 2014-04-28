package ui.vbase {
	
	public class VFill extends VBaseComponent {
		private var color:uint;
		private var $alpha:Number;
		private var round:uint;
		
		public function VFill(color:uint, alpha:Number = 1, round:uint = 0):void {
			mouseEnabled = mouseChildren = false;
			changeEnv(color, alpha, round);
		}
		
		public function changeEnv(color:uint, alpha:Number = 1, round:uint = 0):void {
			this.color = color;
			$alpha = alpha;
			this.round = round;
			if (isGeometryPhase) {
				updatePhase(true);
			}
		}
		
		override protected function customUpdate():void {
			graphics.clear();
			graphics.lineStyle(0, 0, 0, true);
			graphics.beginFill(color, $alpha);
			
			if (round == 0) {
				graphics.drawRect(0, 0, w, h);
			} else {
				graphics.drawRoundRect(0, 0, w, h, round);
			}
		}
		
	} //end class
}