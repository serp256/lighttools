package ui.vbase {
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.events.EventDispatcher;
	import flash.utils.getQualifiedClassName;

	import ui.vtool.VToolPanel;

	/**
	 * Базовый компонент UI
	 *
	 * Термин 1: компоновка - расчет обычных свойств DisplayObject.x,y + абстрактной ширины и высоты (w,h)
	 * Термин 2: w,h - ширина и высота для расчета внутреннего содежимого - других компонентов или любых диспленых объектов
	 * Термин 3: параметры компоновки - набор свойств, на базе которых расчитывается компоновка:
	 * left, right, bottom, vCenter, hCenter, layoutW, layoutH, maxW, maxH, minW, minH
	 * Термин 4: фаза компоновки - вызов метода geometryPhase, который производит компоновку
	 * Термин 5: фаза обновления - обработка дочернего содержимого с учетом w,h
	 * (в общем случае это поочередное применение фазы компоновки и обновления к дочерним элементам)
	 *
	 * Правило 1: если изменены параметры компоновки, то нужно выполнить фазу компоновки (geometryPhase)
	 * Правило 2: w,h может расчитаваться исходя из компоновки дочерних компонентов,
	 * поэтому изменение параметров компоновки дочернего элемента может вызывать фазу компоновки у родителей
	 */
	public class VComponent extends Sprite {
		public static const
			SKIP_CONTENT_SIZE:uint = 2147483648,	//Пропускать компонент при расчете размера содержимого - в методе calcContentSize (1 << 31)
			EMPTY:int = int.MAX_VALUE
			;
		protected static const RULED_LAYOUT:uint = 268435456;
		CONFIG::debug
		public static const V_TOOL_SOLID:uint = 1073741824; //VTool не лезет внутрь компонента
		CONFIG::debug
		public static const V_TOOL_HIDDEN:uint = 536870912;

		//приоритеты
		//w = left+right || layoutW > 0 || isPercentW (layoutW < 0) || contentWidth
		//h = top+bottom || layoutH > 0 || isPercentH (layoutH < 0) || contentHeight
		//x = hCenter || left || right
		//y = vCenter || top || bottom
		public var
			left:int = EMPTY,
			right:int = EMPTY,
			top:int = EMPTY,
			bottom:int = EMPTY,
			vCenter:int = EMPTY,
			hCenter:int = EMPTY,
			layoutW:int,
			layoutH:int,
			maxW:uint,
			maxH:uint,
			minW:uint,
			minH:uint,
			/**
			 * Флаг для уменьшение повторных вычислений
			 */
			isGeometryPhase:Boolean,	//отработала фаза геометрии
			w:uint,						//результат работы geometryPhase
			h:uint,
			validContentSize:Boolean	//показывает, что дефолтный размер расчитан
			;
		private var
			$dispatcher:EventDispatcher = this as EventDispatcher,
			listenerList:Vector.<VOListener>,
			isWaitUpdatePhase:Boolean	//флаг отложенной фазы обновления
			;
		protected var
			updateW:uint = uint.MAX_VALUE,	//ширина последней фазы обновления
			updateH:uint,					//высота последней фазы обновления
			contentW:uint,					//расчетный размер содержимого
			contentH:uint,
			mode:uint
			;
		/**
		 * Хинт
		 * 1) null (не задан), 2) String (выводится переданная строка), 3) Function (будет вызвана функция без аргументов, должна возвращать String || null)
		 */
		public var hint:Object;

		public function getHintData():Object {
			if (hint is Function) {
				return (hint as Function)();
			}
			return hint;
		}

		public function getMode():uint {
			return mode;
		}

		public function set dispatcher(value:EventDispatcher):void {
			$dispatcher = value ? value : this;
		}
		
		public function get dispatcher():EventDispatcher {
			//если $dispatcher является другой BaseComponent, то результатом является его диспачер
			//(это обеспечивает правильный доступ по цепочке диспачеров)
			return ($dispatcher == this || !($dispatcher is VComponent)) ? $dispatcher : ($dispatcher as VComponent).dispatcher;
		}
		
		/**
		 * Добавить слушателя события
		 * Все слушатели добавленный через это метод при вызове dispose будут отписаны
		 * 
		 * @param	type			Тип события
		 * @param	handler			Функция обработчик
		 * @param	dispatcher		Объект, который генерирует событие (если не знадан, то используется сам компонент)
		 * @param	priority		Приоритет события
		 * @param	useCapture		Использовать фазу захвата
		 */
		public function addListener(type:String, handler:Function, dispatcher:EventDispatcher = null, priority:uint = 0, useCapture:Boolean = false):void {
			if (!listenerList) {
				listenerList = new Vector.<VOListener>();
			}
			if (!dispatcher) {
				dispatcher = this;
			}
			var item:VOListener = new VOListener();
			item.dispatcher = dispatcher;
			item.type = type;
			item.handler = handler;
			item.useCapture = useCapture;
			listenerList.push(item);
			
			dispatcher.addEventListener(type, handler, useCapture, priority);
		}
		
		/**
		 * Проверяет наличие слушателя
		 * 
		 * @param	type			Тип события
		 * @param	handler			Функция обработчик
		 * @param	dispatcher		Объект, который генерирует событие (если не знадан, то используется сам компонент)
		 * @param	useCapture		Фаза захвата
		 * @return
		 */
		/*
		public function hasListener(type:String, handler:Function, dispatcher:EventDispatcher = null, useCapture:Boolean = false):Boolean {
			if (listenerList) {
				if (!dispatcher) {
					dispatcher = this;
				}
				for each (var item:VOListener in listenerList) {
					if (item.dispatcher == dispatcher && item.type == type && item.handler == handler && item.useCapture == useCapture) {
						return true;
					}
				}
			}
			return false;
		}
		*/
		
		/**
		 * Удалить слушателя события
		 * 
		 * @param	type			Тип события
		 * @param	handler			Функция обработчик
		 * @param	dispatcher		Объект, который генерирует событие (если не знадан, то используется сам компонент)
		 * @param	useCapture		Фаза захвата
		 */
		public function removeListener(type:String, handler:Function = null, dispatcher:EventDispatcher = null, useCapture:Boolean = false):void {
			if (!listenerList) {
				return;
			}
			if (!dispatcher) {
				dispatcher = this;
			}
			for (var i:int = listenerList.length - 1; i >= 0; i--) {
				var item:VOListener = listenerList[i];
				if (item.dispatcher == dispatcher && item.type == type && item.handler == handler && item.useCapture == useCapture) {
					dispatcher.removeEventListener(item.type, item.handler, item.useCapture);
					listenerList.splice(i, 1);
				}
			}
			if (listenerList.length == 0) {
				listenerList = null;
			}
		}
		
		/**
		 * Видимость компонента
		 * Реализует отложенный вызов фазы обновления
		 */
		override public function set visible(value:Boolean):void {
			super.visible = value;
			if (isWaitUpdatePhase && value) {
				isWaitUpdatePhase = false;
				updatePhase();
			}
		}
		
		/**
		 * Разрушает компонент
		 * Удаляет все listeners, и все BaseComponent находящиеся в дереве дочерних DisplayObject
		 */
		public function dispose():void {
			if (listenerList) {
				for each (var item:VOListener in listenerList) {
					item.dispatcher.removeEventListener(item.type, item.handler, item.useCapture);
				}
				listenerList = null;
			}
			childrenDispose(this);
		}
		
		//рекурсивная функция разрушающая все BaseComponent в дереве дочерних DisplayObject
		protected function childrenDispose(container:DisplayObjectContainer):void {
			for (var i:int = container.numChildren - 1; i >= 0; i--) {
				var component:DisplayObject = container.getChildAt(i);
				if (component is VComponent) {
					(component as VComponent).dispose();
				} else if (component is DisplayObjectContainer) {
					childrenDispose(component as DisplayObjectContainer);
				}
			}
		}
		
		/**
		 * Синхронизировать компоновку
		 * Следует вызывать если изменение идет через свойства VLayout полученного методом getLayout()
		 * Расчет проивзодится если родитель является VBaseComponent и у него уже расчитана геометрия
		 */
		public function syncLayout():void {
			if (parent is VComponent) {
				var p_component:VComponent = parent as VComponent;
				if (isGeometryPhase && p_component.isGeometryPhase) {
					p_component.syncChildLayout(this);
				} else {
					resetValidContentSize(p_component);
				}
			} else if (isGeometryPhase) {
				geometryPhase();
			}
		}

		/**
		 * Изменены параметры компоновки у дочернего компонента
		 * Нужно вызывать если isGeometryPhase == true
		 *
		 * @param  component              Дочерний компонент
		 */
		protected function syncChildLayout(component:VComponent):void {
			validContentSize = false;
			if (isDependentSize && (mode & RULED_LAYOUT) == 0) {
				//w,h могут не изменится и поэтому не будет вызван сustomUpdate
				//поэтому отслеживание изменение флага component.isGeometryPhase
				component.isGeometryPhase = false;
				if (parent is VComponent) {
					(parent as VComponent).syncChildLayout(this);
				} else {
					geometryPhase();
				}
				if (!component.isGeometryPhase) {
					component.geometryPhase();
				}
			} else {
				component.geometryPhase();
			}
		}
		
		/**
		 * Обновлено внутрнее содержимое
		 * Вызывать если изменение внутренних свойств компонента приводит к изменению дефолтных размеров
		 * и требуется обязательный вызов updatePhase
		 * 
		 * @param		invalidContentSize			Сбросить флаг validContentSize в false
		 */
		protected function syncContentSize(invalidContentSize:Boolean):void {
			if (invalidContentSize) {
				validContentSize = false;
			}
			if (isGeometryPhase) {
				if (isDependentSize) {
					updateW = uint.MAX_VALUE;
					if ((mode & RULED_LAYOUT) == 0 && parent is VComponent) {
						(parent as VComponent).syncChildLayout(this);
					} else {
						geometryPhase();
					}
				} else {
					updatePhase(true);
				}
			} else {
				resetValidContentSize(parent as VComponent);
			}
		}

		private function resetValidContentSize(component:VComponent):void {
			while (component) {
				if (component.isDependentSize) {
					component.validContentSize = false;
					component = component.parent as VComponent;
				} else {
					return;
				}
			}
		}
		
		/**
		 * Возвращает layoutW (> 0) или contentWidth
		 * 
		 * @return
		 */
		public function get measuredWidth():uint {
			if (layoutW > 0) {
				return applyRangeW(layoutW);
			}
			if (!validContentSize) {
				calcContentSize();
				validContentSize = true;
			}
			return applyRangeW(contentW);
		}
		
		/**
		 * Возвращает layoutH (> 0) или contentHeight
		 * 
		 * @return
		 */
		public function get measuredHeight():uint {
			if (layoutH > 0) {
				return applyRangeH(layoutH);
			}
			if (!validContentSize) {
				calcContentSize();
				validContentSize = true;
			}
			return applyRangeH(contentH);
		}
		
		/**
		 * Добавить новый дочерний компонент
		 * Групирует addChildAt, set Layout и syncLayout
		 * 
		 * @param	component			Добавляемый компонент
		 * @param	layout				Праметры компоновки
		 * @param	index				Дочерний индекс, если не знадан, то компонент добавляется наверх
		 */
		public function add(component:VComponent, layout:Object = null, index:int = -1):void {
			if (index >= 0 && index < numChildren) {
				addChildAt(component, index);
			} else {
				addChild(component);
			}
			if (layout) {
				component.assignLayout(layout);
			}
			if (isGeometryPhase) {
				syncChildLayout(component);
			} else {
				validContentSize = false;
			}
		}

		public function addStretch(component:VComponent, index:int = -1):void {
			component.stretch();
			add(component, null, index);
		}
		
		/**
		 * Удаление дочернего компонента
		 * 
		 * @param	component		Удаляеый компонент
		 * @param	isDispose		Также произвести вызов dispose
		 */
		public function remove(component:VComponent, isDispose:Boolean = true):void {
			if (component && component.parent == this) {
				removeChild(component);
				if (isDispose) {
					component.dispose();
				} else {
					component.updateW = uint.MAX_VALUE;
					if (component.isDependentSize) {
						component.isGeometryPhase = false;
					}
				}
				validContentSize = false;
				if (isGeometryPhase && isDependentSize) {
					if (parent is VComponent) {
						(parent as VComponent).syncChildLayout(this);
					} else {
						geometryPhase();
					}
				}
			}
		}
		
		/**
		 * Расчитать размер содержимого
		 */
		protected function calcContentSize():void {
			var c_w:uint = 0;
			var c_h:uint = 0;
			for (var i:int = numChildren - 1; i >= 0; i--) {
				var component:VComponent = getChildAt(i) as VComponent;
				if (component && (component.mode & SKIP_CONTENT_SIZE) == 0) {
					//к ширине и высоте добавляем положительные привязки к границе
					var v:uint = component.measuredWidth + component.hPadding;
					if (v > c_w) {
						c_w = v;
					}
					
					v = component.measuredHeight + component.vPadding;
					if (v > c_h) {
						c_h = v;
					}
				}
			}
			contentW = c_w;
			contentH = c_h;
		}
		
		/**
		 * Задает размер компонента и вызывает updatePhase
		 * 
		 * @param	w						Ширина
		 * @param	h						Высота
		 * @param	changeLayoutSize		Изменить размер компонента заданный в layout (использовать для компонентов !(parent is VBaseComponent))
		 */
		public function setGeometrySize(w:uint, h:uint, changeLayoutSize:Boolean):void {
			if (changeLayoutSize) {
				layoutW = w;
				layoutH = h;
			}

			this.w = w;
			this.h = h;
			isGeometryPhase = true;
			updatePhase();
		}
		
		/**
		 * Фаза геометрии компонента
		 * Производится расчет x, y, w, h
		 */
		public function geometryPhase():void {
			isGeometryPhase = true;
			
			if (parent is VComponent) {
				//ширина родителя
				var p_w:uint = (parent as VComponent).w;
				//высота родителя
				var p_h:uint = (parent as VComponent).h;
			}

			//ширина
			if (right != EMPTY && left != EMPTY) {
				w = applyRangeW(p_w - (left + right));
			} else if (layoutW < 0) {
				w = applyRangeW(p_w * (-layoutW / 100));
			} else {
				w = measuredWidth;
			}

			//расчет x
			if (hCenter != EMPTY) {
				x = ((p_w - w) >> 1) + hCenter;
			} else if (left != EMPTY) {
				x = left;
			} else if (right != EMPTY) {
				x = p_w - w - right;
			}

			//высота
			if (bottom != EMPTY && top != EMPTY) {
				h = applyRangeH(p_h - (top + bottom));
			} else if (layoutH < 0) {
				h = applyRangeH(p_h * (-layoutH / 100));
			} else {
				h = measuredHeight;
			}
			
			//расчет y
			if (vCenter != EMPTY) {
				y = ((p_h - h) >> 1) + vCenter;
			} else if (top != EMPTY) {
				y = top;	
			} else if (bottom != EMPTY) {
				y = p_h - h - bottom;
			}
			
			updatePhase();
		}

		/**
		 * Фаза обновления
		 * Производится компоновка содержимого компонента
		 * Ширина и высота будут сохранены, следующее обновление будет произведено только
		 * если новый размер будет отличаться
		 * 
		 * @param		force		Обновление будет произведено даже при кешированном значении
		 */
		public function updatePhase(force:Boolean = false):void {
			if (updateW != w || updateH != h || force) {
				if (visible) {
					updateW = w;
					updateH = h;
					customUpdate();
				} else {
					isWaitUpdatePhase = true;
					if (force) {
						updateW = uint.MAX_VALUE;
					}
				}
			}
		}
		
		/**
		 * Обновление содержимого
		 */
		protected function customUpdate():void {
			for (var i:int = 0; i < numChildren; i++) {
				var obj:DisplayObject = getChildAt(i);
				if (obj is VComponent) {
					(obj as VComponent).geometryPhase();
				}
			}
		}

		/**
		 * Послать VEvent.VARIANCE
		 *
		 * @param  variance    	Вариант
		 * @param  data
		 */
		public function dispatchVarianceEvent(variance:uint, data:* = null):void {
			dispatcher.dispatchEvent(new VEvent(VEvent.VARIANCE, data, variance));
		}

		public function removeAllChildren(isDispose:Boolean = true):void {
			while (numChildren > 0) {
				var obj:DisplayObject = getChildAt(0);
				if (obj is VComponent) {
					remove(obj as VComponent, isDispose);
				} else {
					removeChild(obj);
				}
			}
		}

		public function removeFromParent(isDispose:Boolean = true):void {
			if (parent) {
				if (parent is VComponent) {
					(parent as VComponent).remove(this, false);
				} else {
					parent.removeChild(this);
				}
			}
			if (isDispose) {
				dispose();
			}
		}

		public function addFloat(component:VComponent):void {
			if (!component.parent) {
				add(component);
			}
		}

		public function removeFloat(component:VComponent):void {
			if (component && component.parent == this) {
				remove(component, false);
			}
		}

		public function disposeFloat(component:VComponent):Boolean {
			if (component && !component.parent) {
				component.dispose();
				return true;
			}
			return false;
		}

		public function assignLayout(data:Object = null):void {
			if (data == null) {
				return;
			}
			for (var kind:String in data) {
				var v:int = int(data[kind]);
				switch (kind) {
					case 'left':
						left = v;
						break;

					case 'top':
						top = v;
						break;

					case 'right':
						right = v;
						break;

					case 'bottom':
						bottom = v;
						break;

					case 'w':
						layoutW = v;
						break;

					case 'wP':
						layoutW = -v;
						break;

					case 'h':
						layoutH = v;
						break;

					case 'hP':
						layoutH = -v;
						break;

					case 'hCenter':
						hCenter = v;
						break;

					case 'vCenter':
						vCenter = v;
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
						CONFIG::develop { trace('bad layout value:' + kind); }
				} //end switch
			}
		}

		public function stretch():void {
			layoutW = layoutH = -100;
		}

		public function setSize(w:int, h:int):void {
			layoutW = w;
			layoutH = h;
		}

		public function useCenter(x:int = 0, y:int = 0):void {
			hCenter = x;
			vCenter = y;
		}

		public function setPadding(value:int):void {
			left = right = top = bottom = value;
		}

		/**
		 * Сбросить все параметры в дефолт
		 */
		public function resetLayout():void {
			left = right = top = bottom = vCenter = hCenter = EMPTY;
			maxW = maxH = minW = minH = layoutW = layoutH = 0;
		}

		public function copyLayout(target:VComponent):void {
			left = target.left;
			right = target.right;
			top = target.top;
			bottom = target.bottom;
			vCenter = target.vCenter;
			hCenter = target.hCenter;
			maxW = target.maxW;
			maxH = target.maxH;
			minW = target.minW;
			minH = target.minH;
			layoutW = target.layoutW;
			layoutH = target.layoutH;
		}

		/**
		 * Применить ограничения по ширине
		 *
		 * @param	w		Текущая ширина
		 * @return
		 */
		public function applyRangeW(w:int):uint {
			if (w < minW) {
				return minW;
			} else if (maxW > 0) {
				if (w > maxW) {
					return maxW;
				}
			}
			return w;
		}

		/**
		 * Применить ограничения по высоте
		 *
		 * @param	h		Текущая высота
		 * @return
		 */
		public function applyRangeH(h:int):uint {
			if (h < minH) {
				return minH;
			} else if (maxH > 0) {
				if (h > maxH) {
					return maxH;
				}
			}
			return h;
		}

		public function get hPadding():int {
			var v:uint = 0;
			if (left != EMPTY && left > 0) {
				v += left;
			}
			if (right != EMPTY && right > 0) {
				v += right;
			}
			return v;
		}

		public function get vPadding():int {
			var v:uint = 0;
			if (top != EMPTY && top > 0) {
				v += top;
			}
			if (bottom != EMPTY && bottom > 0) {
				v += bottom;
			}
			return v;
		}

		public function get isLeftRight():Boolean {
			return right != EMPTY && left != EMPTY;
		}

		public function get isTopBottom():Boolean {
			return bottom != EMPTY && top != EMPTY;
		}

		/**
		 * Размер компонента зависит от содержимого, либо родительского компонента
		 */
		private function get isDependentSize():Boolean {
			return layoutW <= 0 || layoutH <= 0 || (right != EMPTY && left != EMPTY) || (bottom != EMPTY && top != EMPTY);
		}

		public function get leftOrZero():int {
			return left != EMPTY ? left : 0;
		}

		public function get rightOrZero():int {
			return right != EMPTY ? right : 0;
		}

		public function get topOrZero():int {
			return top != EMPTY ? top : 0;
		}

		public function get bottomOrZero():int {
			return bottom != EMPTY ? bottom : 0;
		}

		CONFIG::debug
		override public function get name():String {
			var str:String = getQualifiedClassName(this);
			if (this is VSkin) {
				var obj:DisplayObject = (this as VSkin).content;
				if (obj is ScaleSkin) {
					obj = (obj as ScaleSkin).master;
				}
				str += ' (' + VToolPanel.getClassName(obj) + ')';
			}
			return str;
		}

		//возвращает layoutW > 0 || расчитанный w на базе родителя (если parent.layoutW > 0)
		public function calcAccurateW():uint {
			if (layoutW < 0 || isLeftRight) {
				if (parent is VComponent) {
					var component:VComponent = parent as VComponent;
					if (component.layoutW > 0 && !component.isLeftRight) {
						return applyRangeW(isLeftRight ? component.layoutW - (left + right) : component.layoutW * (-layoutW / 100));
					}
				}
			} else if (layoutW > 0) {
				return applyRangeW(layoutW);
			}
			return 0;
		}

		//возвращает layoutH > 0 || расчитанный h на базе родителя (если parent.layoutH > 0)
		public function calcAccurateH():uint {
			if (layoutH < 0 || isTopBottom) {
				if (parent is VComponent) {
					var component:VComponent = parent as VComponent;
					if (component.layoutH > 0 && !component.isTopBottom) {
						return applyRangeH(isTopBottom ? component.layoutH - (top + bottom) : component.layoutH * (-layoutH / 100));
					}
				}
			} else if (layoutH > 0) {
				return applyRangeH(layoutH);
			}
			return 0;
		}

		public function useRuledLayout(flag:Boolean = true):void {
			if (flag) {
				mode |= RULED_LAYOUT;
			} else {
				mode &= ~RULED_LAYOUT;
			}
		}

		CONFIG::debug
		public function useToolSolid():void {
			mode |= V_TOOL_SOLID;
		}

		CONFIG::debug
		public function resetToolSolid():void {
			mode &= ~V_TOOL_SOLID;
		}

		CONFIG::debug
		public function useToolHidden():void {
			mode |= V_TOOL_HIDDEN;
		}

		CONFIG::debug
		public function getToolPropList(out:Array):void {
		}

		CONFIG::debug
		public function updateToolProp(item:VOComponentItem):void {
		}

	} //end class
}