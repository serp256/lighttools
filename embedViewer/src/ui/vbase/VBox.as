package ui.vbase {
	public class VBox extends VComponent {
		public static const
			VERTICAL:uint = 1,
			TOP:uint = 2,			//привязка к верхнему краю
			LEFT:uint = 4,			//привязка к левому краю
			BOTTOM:uint = 8,
			RIGHT:uint = 16,
			STRETCH:uint = 32,		//растягивать компоненты (VERTICAL:true - wP:100, VERTICAL:false - hP:100)
			LIMIT_SIZE:uint = 64,   //ограничивать максимальную ширину (для вертикального) или высоту (для горизонтального) размером бокса
			CENTER:uint = 128,
			MIDDLE:uint = 256
			;
		public var list:Vector.<VComponent>;	//список комопнентов, которые принадлежат списку
		private var $gap:uint;

		/**
		 * Бокс
		 *
		 * @param    list       Список компонентов || null
		 * @param    gap        Расстояние между компонентами
		 * @param    mode       Режимы
		 */
		public function VBox(list:Vector.<VComponent> = null, gap:uint = 5, mode:uint = 0) {
			this.mode = mode;
			$gap = gap;

			if (list) {
				this.list = list;
				var isStretch:Boolean = (mode & STRETCH) != 0;
				for each (var component:VComponent in list) {
					addChild(component);
					if (isStretch) {
						applyStretch(component);
					}
				}
			} else {
				this.list = new Vector.<VComponent>();
			}
		}

		/**
		 * Применить режим растяжения для компонента
		 *
		 * @param    component
		 */
		private function applyStretch(component:VComponent):void {
			if ((mode & VERTICAL) != 0) {
				component.layoutW = -100;
			} else {
				component.layoutH = -100;
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

		override protected function syncChildLayout(component:VComponent):void {
			syncContentSize(true);
		}

		override public function add(component:VComponent, layout:Object = null, index:int = -1):void {
			if (index >= 0 && index < list.length) {
				list.splice(index, 0, component);
			} else {
				list.push(component);
			}
			if (layout) {
				component.assignLayout(layout);
			}
			addChild(component);
			if ((mode & STRETCH) != 0) {
				applyStretch(component);
			}

			if (isGeometryPhase || parent) { //небольшая оптимизация чтобы вхолостую не вызывать syncContentSize
				syncContentSize(true);
			} else {
				validContentSize = false;
			}
		}

		override public function remove(component:VComponent, isDispose:Boolean = true):void {
			var i:int = list.indexOf(component);
			if (i >= 0) {
				removeAt(i, isDispose);
			}
		}

		public function removeAt(index:uint, isDispose:Boolean = true):void {
			if (index < list.length) {
				var component:VComponent = list[index];
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
		 * @param    isDispose        При удалении также вызывать dispose
		 */
		public function removeAll(isDispose:Boolean = true):void {
			if (list && list.length > 0) {
				for each (var component:VComponent in list) {
					removeChild(component);
					if (isDispose) {
						component.dispose();
					}
				}
				list.length = 0;
			}
		}

		public function addAll():void {
			if (list && list.length > 0) {
				for each (var component:VComponent in list) {
					addChild(component);
				}
				syncContentSize(true);
			}
		}

		override protected function calcContentSize():void {
			var c_w:uint = 0;
			var c_h:uint = 0;
			var isVertical:Boolean = (mode & VERTICAL) != 0;
			for each (var component:VComponent in list) {
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
				if ((mode & VERTICAL) != 0) {
					vertical();
				} else {
					horizontal();
				}
			}
			if (list.length != numChildren) {
				updateRuledComponents();
			}
		}

		private function updateRuledComponents():void {
			var i:int = list.length - 1;
			var j:int = numChildren - 1;
			while (j >= 0) {
				var component:VComponent = getChildAt(j) as VComponent;
				if (i < 0 || list[i] != component) {
					if ((component.getMode() & VComponent.RULED_LAYOUT) != 0) {
						component.geometryPhase();
					}
				} else {
					i--;
				}
				j--;
			}
		}

		//--функция горизонтального Box-а--
		private function horizontal():void {
			var total_percent:int = 0; //сумма процентов ширины компонентов (< 0)
			var percent_list:Vector.<uint>; //список % данных
			var sum_w:uint = $gap * (list.length - 1); //суммарная ширина занимаймаемая компонентами
			var w:int = this.w - sum_w; //ширина, которая доступна для компонентов с %-ой шириной
			var b_h:int = this.h; //высота бокса
			const isTop:Boolean = (mode & TOP) != 0;
			const isBottom:Boolean = (mode & BOTTOM) != 0;

			//обработчка точных размеров + Y
			for (var i:int = list.length - 1; i >= 0; i--) {
				var component:VComponent = list[i];

				if (component.isTopBottom) {
					var c_h:int = b_h - component.vPadding;
				} else {
					c_h = component.layoutH < 0 ? b_h * (-component.layoutH / 100) : component.layoutH;
				}
				c_h = (c_h <= 0) ? component.measuredHeight : component.applyRangeH(c_h);
				if (c_h > b_h && (mode & LIMIT_SIZE) != 0) {
					c_h = b_h;
				}

				if (isTop) {
					component.y = 0;
				} else {
					component.y = isBottom ? b_h - c_h : Math.round((b_h - c_h) / 2);
				}

				//запоминаем те компоненты, которые имеют layout.w > 0 и layout.isWPercent
				if (component.layoutW < 0) {
					if (!percent_list) {
						percent_list = new Vector.<uint>();
					}
					percent_list.push(i, c_h);
					total_percent += component.layoutW;
				} else {
					component.setGeometrySize(component.measuredWidth, c_h, false);
					w -= component.w;
					sum_w += component.w;
				}
			}

			//обработка % компонентов
			if (percent_list) {
				var j:uint = percent_list.length - 1;
				for (i = 0; i < j; i = i + 2) {
					component = list[percent_list[i]];
					component.setGeometrySize((w > 0) ? component.applyRangeW((component.layoutW / total_percent) * w) : component.measuredWidth, percent_list[i + 1], false);
					sum_w += component.w;
				}
			}

			//раставляем по X
			if ((mode & CENTER) != 0) {
				i = (this.w - sum_w) / 2;
			} else if ((mode & RIGHT) != 0) {
				i = this.w - sum_w;
			} else {
				i = 0;
			}
			for each (component in list) {
				component.x = i;
				i += component.w + $gap;
			}
		}

		//--функция вертикального Box-а--
		private function vertical():void {
			var total_percent:int = 0; //сумма процентов высоты компонентов (< 0)
			var percent_list:Vector.<uint>; //список % данных
			var sum_h:uint = $gap * (list.length - 1);
			var h:int = this.h - sum_h; //высота, которая доступна для компонентов с %-ой высотой
			var b_w:int = this.w; //ширина бокса
			const isLeft:Boolean = (mode & LEFT) != 0;
			const isRight:Boolean = (mode & RIGHT) != 0;

			//обработчка точных размеров + X
			for (var i:int = list.length - 1; i >= 0; i--) {
				var component:VComponent = list[i];

				if (component.isLeftRight) {
					var c_w:int = b_w - component.hPadding;
				} else {
					c_w = component.layoutW < 0 ? b_w * (-component.layoutW / 100) : component.layoutW;
				}
				c_w = (c_w <= 0) ? component.measuredWidth : component.applyRangeW(c_w);
				if (c_w > b_w && (mode & LIMIT_SIZE) != 0) {
					c_w = b_w;
				}

				if (isLeft) {
					component.x = 0;
				} else {
					component.x = isRight ? b_w - c_w : Math.round((b_w - c_w) / 2);
				}

				//запоминаем те компоненты, которые имеют layout.h > 0 и layout.isHPercent
				if (component.layoutH < 0) {
					if (!percent_list) {
						percent_list = new Vector.<uint>();
					}
					percent_list.push(i, c_w);
					total_percent += component.layoutH;
				} else {
					component.setGeometrySize(c_w, component.measuredHeight, false);
					h -= component.h;
					sum_h += component.h;
				}
			}

			//обработка % компонентов
			if (percent_list) {
				var j:uint = percent_list.length - 1;
				for (i = 0; i < j; i += 2) {
					component = list[percent_list[i]];
					component.setGeometrySize(percent_list[i + 1], (h > 0) ? component.applyRangeH((component.layoutH / total_percent) * h) : component.measuredHeight, false);
					sum_h += component.h;
				}
			}

			//раставляем по Y
			if ((mode & MIDDLE) != 0) {
				i = (this.h - sum_h) / 2;
			} else if ((mode & BOTTOM) != 0) {
				i = this.h - sum_h;
			} else {
				i = 0;
			}
			for each (component in list) {
				component.y = i;
				i += component.h + $gap;
			}
		}


		CONFIG::debug
		override public function getToolPropList(out:Array):void {
			out.push(
				new VOComponentItem('gap', VOComponentItem.DIGIT, gap)
			);
		}

		CONFIG::debug
		override public function updateToolProp(item:VOComponentItem):void {
			if (item.key == 'gap') {
				gap = item.valueInt;
			}
		}

	} //end class
}