package ui.vtool {
	import flash.display.DisplayObject;
	import flash.events.MouseEvent;
	import flash.utils.getQualifiedClassName;
	import ui.vbase.*;
	
	public class CaptureItemRenderer extends VAbstractItemRenderer {
		private var label:VLabel = new VLabel(null, VLabel.CONTAIN | VLabel.VERTICAL_MIDDLE);
		public var target:DisplayObject;
		
		public function CaptureItemRenderer():void {
			layout.w = 100;
			layout.h = 16;
			add(new VFill(0xFCFDB3), { w:'100%', h:'100%' } );
			add(label, { w:'100%', h:'100%' } );
			buttonMode = true;
			mouseChildren = false;
			addListener(MouseEvent.CLICK, onClickHandler);
		}
		
		override public function setData(data:Object):void {
			target = data as DisplayObject;
			
			if (target) {
				var str:String = '<p fontSize="12" color="' + ((target == ComponentPanel.target) ? '0xFF0000" fontWeight="bold"' : '0x591100"') + '>' +
					getQualifiedClassName(target);
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
		
		private function onClickHandler(event:MouseEvent):void {
			dispatcher.dispatchEvent(new VEvent(VEvent.SELECT, target));
		}
		
	} //end class
}