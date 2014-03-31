package ui.vbase {
	import flash.display.Shape;
	
	public class VProgressBar extends VBaseComponent {
		private var skin:VSkin;
		private var indicator:VSkin;
		protected var $value:Number = 0;
		private var maskShape:Shape;
		
		/**
		 * Создает ProgressBar
		 * 
		 * @param	skin					Задний скин
		 * @param	indicator				Индикатор
		 * @param	masked					Использовать маскирующее изменение
		 */
		public function VProgressBar(skin:VSkin, indicator:VSkin, masked:Boolean = false):void {
			mouseChildren = false;
			
			this.skin = skin;
			this.indicator = indicator;
			if (skin) {
				addChild(skin);
			}
			addChild(indicator);
			
			if (masked) {
				maskShape = new Shape();
				addChild(maskShape);
				indicator.mask = maskShape;
			}
		}
		
		private function updateIndicator():void {
			var w:Number = Math.round(indicator.w * $value);
			if (maskShape) {
				maskShape.graphics.clear();
				maskShape.graphics.beginFill(0);
				maskShape.graphics.drawRect(0, 0, w, indicator.h);
			} else {
				indicator.width = w;
			}
		}
		
		public function set value(v:Number):void {
			if (v < 0) {
				v = 0;
			} else if (v > 1) {
				v = 1;
			}
			$value = v;
			if (isGeometryPhase) {
				if (visible) {
					updateIndicator();
				}
			}
		}
		
		public function get value():Number {
			return $value;
		}
		
		override protected function customUpdate():void {
			super.customUpdate();
			if (maskShape) {
				maskShape.x = indicator.x;
				maskShape.y = indicator.y;
			}
			updateIndicator();
		}
		
	} //end class
}