package ui.vtool {
	import flash.display.Sprite;
	import flash.geom.Point;
	import ui.vbase.*;
	import flash.events.MouseEvent;
	
	public class LayoutPanel extends VBaseComponent {
		private var lb:VBaseComponent = new VBaseComponent();
		private var rb:VBaseComponent = new VBaseComponent();
		private var tb:VBaseComponent = new VBaseComponent();
		private var bb:VBaseComponent = new VBaseComponent();
		private var cb:VBaseComponent = new VBaseComponent();
		private var curPos:Point = new Point();
		
		public function LayoutPanel():void {
			add(lb, { left:-2, vCenter:0, w:4, h:4 } );
			add(rb, { right:-2, vCenter:0, w:4, h:4 } );
			add(tb, { top:-2, hCenter:0, w:4, h:4 } );
			add(bb, { bottom:-2, hCenter:0, w:4, h:4 } );
			add(cb, { hCenter:0, vCenter:0, w:12, h:12 } );
			
			lb.buttonMode = true;
			rb.buttonMode = true;
			bb.buttonMode = true;
			tb.buttonMode = true;
			cb.buttonMode = true;
			addListener(MouseEvent.MOUSE_DOWN, onMouseDownHandler, cb);
			
			cb.graphics.beginFill(0x009900, .3);
			cb.graphics.drawRect(0, 0, 12, 12);
		}
		
		override protected function customUpdate():void {
			graphics.clear();
			graphics.lineStyle(1, 0x003300);
			graphics.drawRect(0, 0, w, h);
			
			super.customUpdate();
			
			lb.graphics.clear();
			lb.graphics.beginFill(0, 0);
			lb.graphics.drawRect(-1, 1, 6, h - 2);
			lb.graphics.beginFill(0x009900);
			lb.graphics.drawRect(0, 0, 4, 4);
			
			rb.graphics.clear();
			rb.graphics.beginFill(0, 0);
			rb.graphics.drawRect(-1, 1, 6, h - 2);
			rb.graphics.beginFill(0x009900);
			rb.graphics.drawRect(0, 0, 4, 4);
			
			bb.graphics.clear();
			bb.graphics.beginFill(0, 0);
			bb.graphics.drawRect(1, -1, w - 2, 6);
			bb.graphics.beginFill(0x009900);
			bb.graphics.drawRect(0, 0, 4, 4);
			
			tb.graphics.clear();
			tb.graphics.beginFill(0, 0);
			tb.graphics.drawRect(1, -1, w - 2, 6);
			tb.graphics.beginFill(0x009900);
			tb.graphics.drawRect(0, 0, 4, 4);
		}
		
		private function onMouseDownHandler(event:MouseEvent):void {
			curPos.x = event.stageX;
			curPos.y = event.stageY;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMoveHandler);
			stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUpHandler);
		}
		
		private function onStageMouseMoveHandler(event:MouseEvent):void {
			if (Math.abs(curPos.x - event.stageX) >= 1 || Math.abs(curPos.y - event.stageY) >= 1) {
				//dispatcher.dispatchEvent(new VEvent.SELECT, 
			}
		}
		
		private function onStageMouseUpHandler(event:MouseEvent):void {
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMoveHandler);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUpHandler);
		}
		
	} //end class
}