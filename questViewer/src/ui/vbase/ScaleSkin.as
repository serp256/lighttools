package ui.vbase {
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	
	public class ScaleSkin extends MovieClip {
		private var bitmapTL:DisplayObject;
		private var bitmapTC:DisplayObject;
		private var bitmapTR:DisplayObject;
		private var bitmapML:DisplayObject;
		private var bitmapMC:DisplayObject;
		private var bitmapMR:DisplayObject;
		private var bitmapBL:DisplayObject;
		private var bitmapBC:DisplayObject;
		private var bitmapBR:DisplayObject;
		public var master:DisplayObject;
		
		public static function create(master:DisplayObject):DisplayObject {
			return (master is Sprite && (master as Sprite).scale9Grid != null) ? new ScaleSkin(master) : master;
		}
		
		public function ScaleSkin(master:DisplayObject):void {
			mouseChildren = false;
			this.master = master;
			update();
		}
		
		override public function gotoAndStop(frame:Object, scene:String  = null):void {
			if (master is MovieClip) {
				var mc:MovieClip = master as MovieClip;
				var i:int = mc.currentFrame;
				mc.gotoAndStop(frame);
				if (i != mc.currentFrame) {
					var w:Number = width;
					var h:Number = height;
					update();
					width = w;
					height = h;
				}
			}
		}
		
		public function update():void {
			while (numChildren > 0) removeChildAt(0);
			
			var scaleGrid:Rectangle = master.scale9Grid;
			bitmapTL = addChild(slice(master, 0, 0, scaleGrid.x, scaleGrid.y));
			bitmapTC = addChild(slice(master, scaleGrid.x, 0, scaleGrid.width, scaleGrid.y));
			bitmapTR = addChild(slice(master, scaleGrid.right, 0, master.width - scaleGrid.right, scaleGrid.y));
			
			bitmapML = addChild(slice(master, 0, scaleGrid.y, scaleGrid.x, scaleGrid.height));
			bitmapMC = addChild(slice(master, scaleGrid.x, scaleGrid.y, scaleGrid.width, scaleGrid.height));
			bitmapMR = addChild(slice(master, scaleGrid.right, scaleGrid.y, bitmapTR.width, scaleGrid.height));
			
			bitmapBL = addChild(slice(master, 0, scaleGrid.bottom, scaleGrid.x, master.height - scaleGrid.bottom));
			bitmapBC = addChild(slice(master, scaleGrid.x, scaleGrid.bottom, scaleGrid.width, bitmapBL.height));
			bitmapBR = addChild(slice(master, scaleGrid.right, scaleGrid.bottom, bitmapTR.width, bitmapBL.height));
		}
		
		private static function slice(master:DisplayObject, x:Number, y:Number, w:Number, h:Number):DisplayObject {
			var bd:BitmapData = new BitmapData(Math.ceil(w), Math.ceil(h), true, 0);
			var m:Matrix = new Matrix();
			m.translate(-x, -y);
			bd.draw(master, m);
			
			var sp:Sprite = new Sprite();
			sp.graphics.beginBitmapFill(bd, null, false, true); //, true
			sp.graphics.drawRect(0, 0, bd.width, bd.height);
			sp.graphics.endFill();
			
			sp.x = x;
			sp.y = y;
			
			return sp;
		}
		
		override public function set width(value:Number):void {
			var targetWidth:Number = value - bitmapTL.width - bitmapTR.width;
			var targetX:Number = value - bitmapTR.width;
			
			bitmapTC.width = targetWidth;
			bitmapMC.width = targetWidth;
			bitmapBC.width = targetWidth;
			
			bitmapTR.x = targetX;
			bitmapMR.x = targetX;
			bitmapBR.x = targetX;
		}
		
		override public function set height(value:Number):void {
			var targetHeight:Number = value - bitmapTL.height - bitmapBL.height;
			var targetY:Number = value - bitmapBL.height;
			
			bitmapML.height = targetHeight;
			bitmapMC.height = targetHeight;
			bitmapMR.height = targetHeight;
			
			bitmapBL.y = targetY;
			bitmapBC.y = targetY;
			bitmapBR.y = targetY;
		}
	} //end class
}