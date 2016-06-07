package ui.vtool {
	import flash.display.DisplayObject;
	import flash.events.MouseEvent;
	import flash.utils.getQualifiedClassName;

	import ui.vbase.ScaleSkin;
	import ui.vbase.VEvent;
	import ui.vbase.VFill;
	import ui.vbase.VLabel;
	import ui.vbase.VRenderer;
	import ui.vbase.VSkin;

	public class CaptureRenderer extends VRenderer {
		private const label:VLabel = new VLabel(null, VLabel.CONTAIN | VLabel.MIDDLE);
		private var target:DisplayObject;
		
		public function CaptureRenderer() {
			setSize(100, 16);
			addStretch(new VFill(0xFCFDB3));
			label.layoutW = -100;
			label.vCenter = 2;
			addChild(label);
			buttonMode = true;
			mouseChildren = false;
			addListener(MouseEvent.CLICK, onClick);
			addListener(MouseEvent.ROLL_OVER, onRoll);
			addListener(MouseEvent.ROLL_OUT, onRoll);
		}
		
		override public function setData(data:Object):void {
			target = data as DisplayObject;
			
			if (target) {
				var str:String = '<p fontSize="12" fontFamily="Myriad Pro" color="' +
					((target == ComponentPanel.target) ? '0xFF0000" fontWeight="bold"' : '0x591100"') + '>' +
					getQualifiedClassName(target)
				;
				if (target is VSkin) {
					var obj:DisplayObject = (target as VSkin).content;
					if (obj is ScaleSkin) {
						obj = (obj as ScaleSkin).master;
					}
					str += ' (' + VToolPanel.getClassName(obj) + ')';
				}
				str += '</p>';
			}
			
			label.text = str;
		}
		
		private function onClick(event:MouseEvent):void {
			dispatcher.dispatchEvent(new VEvent(VEvent.SELECT, target));
		}

		private function onRoll(event:MouseEvent):void {
			dispatchVarianceEvent(event.type == MouseEvent.ROLL_OVER ? 1 : 2, target);
		}
		
	} //end class
}