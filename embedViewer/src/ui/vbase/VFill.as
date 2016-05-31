package ui.vbase {

	public class VFill extends VComponent {
		private var
			fillColor:uint,
			fillAlpha:Number,
			round:uint,
			thickness:Number,
			lineColor:uint,
			lineAlpha:Number = 1
			;

		public function VFill(fillColor:uint, fillAlpha:Number = 1, round:uint = 0) {
			mouseEnabled = mouseChildren = false;
			setFill(fillColor, fillAlpha, round);
		}

		public function setLine(thickness:Number, color:uint, alpha:Number = 1):void {
			this.thickness = thickness;
			lineColor = color;
			lineAlpha = alpha;
			if (isGeometryPhase) {
				updatePhase(true);
			}
		}

		public function setFill(color:uint, alpha:Number = 1, round:uint = 0):void {
			fillColor = color;
			fillAlpha = alpha;
			this.round = round;
			if (isGeometryPhase) {
				updatePhase(true);
			}
		}

		override protected function customUpdate():void {
			graphics.clear();
			var isLine:Boolean = !isNaN(thickness);
			if (isLine) {
				graphics.lineStyle(thickness, lineColor, lineAlpha, true);
			}
			if (fillAlpha > 0 || !isLine) {
				graphics.beginFill(fillColor, fillAlpha);
			}
			if (round == 0) {
				graphics.drawRect(0, 0, w, h);
			} else {
				graphics.drawRoundRect(0, 0, w, h, round);
			}
			graphics.endFill();
		}

		CONFIG::debug
		override public function getToolPropList(out:Array):void {
			out.push(
				new VOComponentItem('fColor', VOComponentItem.TEXT, fillColor.toString(16)),
				new VOComponentItem('fAlpha', VOComponentItem.DIGIT, 255 * fillAlpha)
			);
		}

		CONFIG::debug
		override public function updateToolProp(item:VOComponentItem):void {
			switch (item.key) {
				case 'fColor':
					setFill(parseInt(item.valueString, 16), fillAlpha);
					break;

				case 'fAlpha':
					setFill(fillColor, item.valueInt / 255);
					break;
			}
		}

	} //end class
}