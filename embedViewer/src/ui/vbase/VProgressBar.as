package ui.vbase {
	import flash.display.Shape;

	public class VProgressBar extends VComponent {
		protected var
			_value:Number = 0,
			indicator:VSkin,
			maskShape:Shape
			;
		public var isFlip:Boolean;

		public function VProgressBar() {
			mouseChildren = false;
			CONFIG::debug {
				useToolSolid();
			}
		}

		/**
		 * @param	indicator				Индикатор
		 * @param	track					Задний скин
		 * @param	masked					Использовать маскирующее изменение
		 */
		public function init(indicator:VSkin, track:VSkin = null, masked:Boolean = false):void {
			this.indicator = indicator;
			if (track) {
				addChild(track);
			}
			addChild(indicator);

			if (masked) {
				maskShape = new Shape();
				addChild(maskShape);
				indicator.mask = maskShape;
			}
		}
		
		protected function updateIndicator():void {
			var w:Number = Math.round(indicator.w * _value);
			if (maskShape) {
				maskShape.graphics.clear();
				maskShape.graphics.beginFill(0);
				maskShape.graphics.drawRect(isFlip ? this.w - w : 0, 0, w, indicator.h);
			} else {
				indicator.width = w;
				if (isFlip) {
					indicator.x = this.w - w;
				}
			}
		}

		public function getIndicator():VSkin {
			return indicator;
		}
		
		public function set value(v:Number):void {
			if (v < 0) {
				v = 0;
			} else if (v > 1) {
				v = 1;
			}
			_value = v;
			if (isGeometryPhase && visible) {
				updateIndicator();
			}
		}
		
		public function get value():Number {
			return _value;
		}
		
		override protected function customUpdate():void {
			super.customUpdate();
			if (maskShape) {
				maskShape.x = indicator.x;
				maskShape.y = indicator.y;
			}
			updateIndicator();
		}

		CONFIG::debug
		override public function getToolPropList(out:Array):void {
			out.push(
				new VOComponentItem('value', VOComponentItem.DIGIT, Math.round(_value * 100))
			);
		}

		CONFIG::debug
		override public function updateToolProp(item:VOComponentItem):void {
			if (item.key == 'value') {
				value = item.valueInt / 100;
			}
		}

	} //end class
}