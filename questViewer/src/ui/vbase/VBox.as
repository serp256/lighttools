package ui.vbase {

	public class VBox extends VBaseComponent {
		/**
		 * TOP || LEFT Align
		 * привязка к верхнему/левому краю
		 */
		public static const TL_ALIGN:uint = 0;
		/**
		 * CENTER Align
		 * привязка к центру
		 */
		public static const C_ALIGN:uint = 1;
		/**
		 * BOTTOM || RIGHT Align
		 * привязка к нижнему/правому краю
		 */
		public static const BR_ALIGN:uint = 2;
		
		public var list:Vector.<VBaseComponent>; //список комопнентов, которые принадлежат списку
		private var isVertical:Boolean;
		private var $gap:uint;
		private var $align:uint;
		private var isStretch:Boolean;
		
		/**
		 * Бокс
		 * 
		 * @param	list			Список компонентов || null
		 * @param	isVertical		Тип расположения: true - вертикальное, false - горизонтальное
		 * @param	gap				Расстояние между компонентами
		 * @param	align			Выравнивание компонентов (isVertical:true - относительно горизонтали, isVertical:false - относительно вертикали)
		 * @param	isStretch		Растягивать компоненты (isVertical:true - w:'100%', isVertical:false - h:'100%'
		 */
		public function VBox(list:Vector.<VBaseComponent>, isVertical:Boolean = true, gap:uint = 5, align:uint = C_ALIGN, isStretch:Boolean = false):void {
			this.isVertical = isVertical;
			$gap = gap;
			$align = align;
			this.isStretch = isStretch;
			
			if (list) {
				this.list = list;
				for each (var component:VBaseComponent in list) {
					addChild(component);
					if (isStretch) {
						applyStretch(component);
					}
				}
			} else {
				this.list = new Vector.<VBaseComponent>();
			}
		}
		
		/**
		 * Применить режим растяжения для компонента
		 * 
		 * @param	component
		 */
		private function applyStretch(component:VBaseComponent):void {
			var layout:VLayout = component.getLayout();
			if (isVertical) {
				layout.w = 100;
				layout.isWPercent = true;
			} else {
				layout.h = 100;
				layout.isHPercent = true;
			}
		}
		
		/**
		 * Расстояние между элементами
		 */
		public function set gap(value:uint):void {
			$gap = value;
			syncContentSize(true);
		}
		
		public function get gap():uint {
			return $gap;
		}
		
		/**
		 * Выравнивание элементов зависит от типа расположения
		 * Одна из констант: TL_ALIGN (привязка к верхнему/левому краю), C_ALIGN (по центру), BR_ALIGN (нижнему/правому краю)
		 */
		public function set align(value:uint):void {
			$align = value;
			if (isGeometryPhase) {
				updatePhase(true);
			}
		}
		
		public function get align():uint {
			return $align;
		}
		
		override protected function syncChildLayout(component:VBaseComponent):void {
			syncContentSize(true);
		}
		
		override public function add(component:VBaseComponent, layout:Object = null, index:int = -1):void {
			if (index >= 0 && index < list.length) {
				list.splice(index, 0, component);
			} else {
				list.push(component);
			}
			if (layout) {
				component.getLayout().assign(layout);
			}
			addChild(component);
			if (isStretch) {
				applyStretch(component);
			}
			
			if (isGeometryPhase || parent) { //небольшая оптимизация чтобы вхолостую не вызывать syncContentSize
				syncContentSize(true);
			} else {
				validContentSize = false;
			}
		}
		
		public function addList(list:Array):void {
			for each (var component:VBaseComponent in list) {
				addChild(component);
				this.list.push(component);
			}
			syncContentSize(true);
		}
		
		override public function remove(component:VBaseComponent, isDispose:Boolean = true):void {
			var i:int = list.indexOf(component);
			if (i >= 0) {
				removeAt(i, isDispose);
			}
		}
		
		public function removeAt(index:uint, isDispose:Boolean = true):void {
			if (index < list.length) {
				var component:VBaseComponent = list[index];
				list.splice(index, 1);
				if (isDispose) {
					component.dispose();
				}
				if (component.parent == this) {
					removeChild(component);
				}
				syncContentSize(true);
			}
		}
		
		/**
		 * Удалить весь дочерний список
		 * 
		 * @param	isDispose		При удалении также вызывать dispose
		 */
		public function removeAll(isDispose:Boolean = true):void {
			if (list) {
				for each (var component:VBaseComponent in list) {
					removeChild(component);
					if (isDispose) {
						component.dispose();
					}
				}
				list.length = 0;
			}
		}
		
		override protected function calcContentSize():void {
			var c_w:uint;
			var c_h:uint;
			for each (var component:VBaseComponent in list) {
				var w:uint = component.measuredWidth;
				var h:uint = component.measuredHeight;
				if (isVertical) { //для вертикального максимум w и суммарный h
					if (w > c_w) {
						c_w = w;
					}
					c_h += h;
				} else { //для горизонтального максимум h и суммарный w
					if (h > c_h) {
						c_h = h;
					}
					c_w += w;
				}
			}
			if (list.length > 0) {
				var gap:uint = (list.length - 1) * $gap;
				if (isVertical) {
					c_h += gap;
				} else {
					c_w += gap;
				}
			}
			
			contentW = c_w;
			contentH = c_h;
		}
		
		override protected function customUpdate():void {
			if (list.length > 0) {
				if (isVertical) {
					vertical();
				} else {
					horizontal();
				}
			}
		}
		
		//--функция горизонтального Box-а--
		private function horizontal():void {
			var total_percent:uint; //сумма процентов ширины компонентов
			var percent_list:Vector.<uint>; //список % данных
			var w:int = this.w - ($gap * (list.length - 1)); //ширина, которая доступна для компонентов с %-ой шириной
			var b_h:int = this.h; //высота бокса
			
			//обработчка точных размеров + Y
			for (var i:int = list.length - 1; i >= 0; i--) {
				var component:VBaseComponent = list[i];
				var layout:VLayout = component.getLayout();
				
				if (layout.top >= 0 && layout.bottom >= 0) {
					var c_h:uint = b_h - (layout.top + layout.bottom);
				} else {
					c_h = (layout.isHPercent) ? b_h * (layout.h / 100) : layout.h;
				}
				if (c_h == 0) {
					c_h = component.contentHeight;
				}
				c_h = layout.applyRangeH(c_h);
				
				if ($align != TL_ALIGN) {
					component.y = ($align == C_ALIGN) ? (b_h - c_h) >> 1 : b_h - c_h;
				} else {
					component.y = 0;
				}
				
				//запоминаем те компоненты, которые имеют layout.w > 0 и layout.isWPercent
				if (layout.w > 0 && layout.isWPercent) {
					if (!percent_list) {
						percent_list = new Vector.<uint>();
					}
					percent_list.push(i, c_h);
					total_percent += layout.w;
				} else {
					var c_w:uint = layout.applyRangeW((layout.w > 0) ? layout.w : component.contentWidth);
					component.setGeometrySize(c_w, c_h, false);
					w -= c_w;
				}
			}
			
			//обработка % компонентов
			if (percent_list) {
				var j:uint = percent_list.length - 1;
				for (i = 0; i < j; i = i + 2) {
					component = list[percent_list[i]];
					layout = component.getLayout();
					if (w > 0) {
						c_w = (layout.w / total_percent) * w;
					} else {
						c_w = component.contentHeight;
					}
					component.setGeometrySize(layout.applyRangeW(c_w), percent_list[i + 1], false);
				}
			}
			
			//раставляем по X
			i = 0;
			for each (component in list) {
				component.x = i;
				i += component.w + $gap;
			}
		}
		
		//--функция вертикального Box-а--
		private function vertical():void {
			var total_percent:uint; //сумма процентов высоты компонентов
			var percent_list:Vector.<uint>; //список % данных
			var h:int = this.h - ($gap * (list.length - 1)); //высота, которая доступна для компонентов с %-ой высотой
			var b_w:int = this.w; //ширина бокса
			
			//обработчка точных размеров + X
			for (var i:int = list.length - 1; i >= 0; i--) {
				var component:VBaseComponent = list[i];
				var layout:VLayout = component.getLayout();
				
				if (layout.left >= 0 && layout.right >= 0) {
					var c_w:uint = b_w - (layout.left + layout.right);
				} else {
					c_w = (layout.isWPercent) ? b_w * (layout.w / 100) : layout.w;
				}
				if (c_w == 0) {
					c_w = component.contentWidth;
				}
				c_w = layout.applyRangeW(c_w);
				
				if ($align != TL_ALIGN) {
					component.x = ($align == C_ALIGN) ? Math.round((b_w - c_w) * .5) : b_w - c_w;
				} else {
					component.x = 0;
				}
				
				//запоминаем те компоненты, которые имеют layout.h > 0 и layout.isHPercent
				if (layout.h > 0 && layout.isHPercent) {
					if (!percent_list) {
						percent_list = new Vector.<uint>();
					}
					percent_list.push(i, c_w);
					total_percent += layout.h;
				} else {
					var c_h:uint = layout.applyRangeH((layout.h > 0) ? layout.h : component.contentHeight);
					component.setGeometrySize(c_w, c_h, false);
					h -= c_h;
				}
			}
			
			//обработка % компонентов
			if (percent_list) {
				var j:uint = percent_list.length - 1;
				for (i = 0; i < j; i = i + 2) {
					component = list[percent_list[i]];
					layout = component.getLayout();
					if (h > 0) {
						c_h = (layout.h / total_percent) * h;
					} else {
						c_h = component.contentHeight;
					}
					component.setGeometrySize(percent_list[i + 1], layout.applyRangeH(c_h), false);
				}
			}
			
			//раставляем по Y
			i = 0;
			for each (component in list) {
				component.y = i;
				i += component.h + $gap;
			}
		}
		
	} //end class
}