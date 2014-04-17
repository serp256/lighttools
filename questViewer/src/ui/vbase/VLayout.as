package ui.vbase {
	import flash.display.DisplayObject;
	import flash.geom.Rectangle;
	
	public class VLayout {
		public var left:int = int.MIN_VALUE;
		public var right:int = int.MIN_VALUE
		public var top:int = int.MIN_VALUE;
		public var bottom:int = int.MIN_VALUE;
		public var vCenter:int;
		public var isVCenter:Boolean;
		public var hCenter:int;
		public var isHCenter:Boolean;
		public var w:uint;
		public var h:uint;
		public var isWPercent:Boolean;
		public var isHPercent:Boolean;
		public var maxW:uint;
		public var maxH:uint;
		public var minW:uint;
		public var minH:uint;
		
		public function assign(data:Object = null):void {
			if (data == null) {
				return;
			}
			for (var kind:String in data) {
				var v:* = data[kind];
				switch (kind) {
					case 'left':
						left = v;
						break;
						
					case 'right':
						right = v;
						break;
						
					case 'top':
						top = v;
						break;
						
					case 'bottom':
						bottom = v;
						break;
						
					case 'w':
						if (v is String) {
							w = uint((v as String).substr(0, -1));
							isWPercent = true;
						} else {
							w = v;
							isWPercent = false;
						}
						break;
						
					case 'h':
						if (v is String) {
							h = uint((v as String).substr(0, -1));
							isHPercent = true;
						} else {
							h = v;
							isHPercent = false;
						}
						break;
						
					case 'hCenter':
						hCenter = v;
						isHCenter = true;
						break;
						
					case 'vCenter':
						vCenter = v;
						isVCenter = true;
						break;
						
					case 'maxW':
						maxW = v;
						break;
						
					case 'minW':
						minW = v;
						break;
						
					case 'maxH':
						maxH = v;
						break;
						
					case 'minH':
						minH = v;
						break;
						
					default:
						trace('bad layout value:' + kind);
				} //end switch
			}
		}
		
		/**
		 * Сбросить все параметры в дефолт
		 */
		public function reset():void {
			left = int.MIN_VALUE;
			right = int.MIN_VALUE
			top = int.MIN_VALUE;
			bottom = int.MIN_VALUE;
			vCenter = 0;
			hCenter = 0;
			isVCenter = false;
			isHCenter = false;
			w = 0;
			h = 0;
			isWPercent = false;
			isHPercent = false;
			maxW = 0;
			maxH = 0;
			minW = 0;
			minH = 0;
		}
		
		/**
		 * Применить ограничения по ширине
		 * 
		 * @param	h		Текущая ширина
		 * @return
		 */
		public function applyRangeW(w:uint):uint {
			if (minW > 0 && w < minW) {
				w = minW;
			} else if (maxW > 0 && w > maxW) {
				w = maxW;
			}
			return w;
		}
		
		/**
		 * Применить ограничения по высоте
		 * 
		 * @param	h		Текущая высота
		 * @return
		 */
		public function applyRangeH(h:uint):uint {
			if (minH > 0 && h < minH) {
				h = minH;
			} else if (maxH > 0 && h > maxH) {
				h = maxH;
			}
			return h;
		}
		
		public function get correctLeft():int {
			return (left != int.MIN_VALUE) ? left : 0;
		}
		
		public function get correctRight():int {
			return (right != int.MIN_VALUE) ? right : 0;
		}
		
		public function get correctTop():int {
			return (top != int.MIN_VALUE) ? top : 0;
		}
		
		public function get correctBottom():int {
			return (bottom != int.MIN_VALUE) ? bottom : 0;
		}

		public function get hPadding():int {
			var v:int;
			if (left != int.MIN_VALUE) {
				v += left;
			}
			if (right != int.MIN_VALUE) {
				v += right;
			}
			return v;
		}

		public function get vPadding():int {
			var v:int;
			if (top != int.MIN_VALUE) {
				v += top;
			}
			if (bottom != int.MIN_VALUE) {
				v += bottom;
			}
			return v;
		}
		
		//======================
		
		public static function center(component:DisplayObject, target:Object):void {
			if (target is DisplayObject) {
				target = new Rectangle(target.x, target.y, target.width, target.height);
			}
			var rect:Rectangle = target as Rectangle;
			if (rect) {
				component.x = rect.x + (rect.width - component.width) * .5;
				component.y = rect.y + (rect.height - component.height) * .5;
			}
		}
		
		/**
		 * Вписать объект в размер с учетом его пропорции
		 * 
		 * @param	obj				Целевой объект
		 * @param	w				Ширина вписывания
		 * @param	h				Высота
		 * @param	noIncrease		Не растягивать объект большe масштаба 1
		 */
		public static function applySize(obj:DisplayObject, w:Number, h:Number, noIncrease:Boolean = false):void {
			if (noIncrease && obj.width <= w && obj.height <= h) {
				return;
			}
			if (w / h <= obj.width / obj.height) {
				obj.width = w;
				obj.scaleY = obj.scaleX;
			} else {
				obj.height = h;
				obj.scaleX = obj.scaleY;
			}
		}
		
	} //end class
}