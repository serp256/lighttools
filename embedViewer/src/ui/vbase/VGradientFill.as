package ui.vbase {
	import flash.display.GradientType;
	import flash.geom.Matrix;

	public class VGradientFill extends VComponent {
		private var
			fillColors:Array,
			fillAlphas:Array,
			fillRatios:Array,
			gradientType:String,
			rotate:Number = 0
			;

		public function VGradientFill() {
			mouseEnabled = mouseChildren = false;
		}

		public function setFill(colors:Array, alphas:Array, ratios:Array, rotate:Number = 0, gradientType:String = GradientType.LINEAR):void {
			fillColors = colors;
			fillAlphas = alphas;
			fillRatios = ratios;
			this.gradientType = gradientType;
			this.rotate = rotate;
			if (isGeometryPhase) {
				updatePhase(true);
			}
		}

		override protected function customUpdate():void {
			graphics.clear();
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(w, h, rotate);
			graphics.beginGradientFill(gradientType, fillColors, fillAlphas, fillRatios, matrix);
			graphics.drawRect(0, 0, w, h);
			graphics.endFill();
		}

	} //end class
}