package ui.vbase {
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.events.EventDispatcher;
	
	/**
	 * Базовый компонент UI
	 */
	public class VBaseComponent extends Sprite {
		private var $dispatcher:EventDispatcher = this as EventDispatcher;
		private var listenerList:Vector.<VOListener>;
		
		protected var layout:VLayout = new VLayout(); //параметры компоновки
		private var $w:uint;
		private var $h:uint;
		
		private var isWaitUpdatePhase:Boolean; //флаг отложенной фазы обновления
		public var isGeometryPhase:Boolean; //отработала фаза геометрии
		protected var updateW:uint; //ширина последней фазы обновления
		protected var updateH:uint; //высота последней фазы обновления
		protected var validContentSize:Boolean; //показывает, что дефолтный размер расчитан
		protected var contentW:uint; //расчетный размер содержимого
		protected var contentH:uint;
		
		/**
		 * Хинт
		 * 1) null (не задан), 2) String (выводится переданная строка), 3) Function (будет вызвана функция, которая обязана принимать компонент и возвращать String || null)
		 */
		public var hint:Object;
		
		public function set dispatcher(value:EventDispatcher):void {
			$dispatcher = value ? value : this;
		}
		
		public function get dispatcher():EventDispatcher {
			//если $dispatcher является другой BaseComponent, то результатом является его диспачер
			//(это обеспечивает правильный доступ по цепочке диспачеров)
			return ($dispatcher == this || !($dispatcher is VBaseComponent)) ? $dispatcher : ($dispatcher as VBaseComponent).dispatcher;
		}
		
		/**
		 * Добавить слушателя события
		 * Все слушатели добавленный через это метод при вызове dispose будут отписаны
		 * 
		 * @param	type			Тип события
		 * @param	handler			Функция обработчик
		 * @param	dispatcher		Объект, который генерирует событие (если не знадан, то используется сам компонент)
		 * @param	useCapture		Использовать фазу захвата
		 * @param	priority		Приоритет события
		 */
		public function addListener(type:String, handler:Function, dispatcher:EventDispatcher = null, useCapture:Boolean = false, priority:uint = 0):void {
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
		
		/**
		 * Удалить слушателя события
		 * 
		 * @param	type			Тип события
		 * @param	handler			Функция обработчик
		 * @param	dispatcher		Объект, который генерирует событие (если не знадан, то используется сам компонент)
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
				if (component is VBaseComponent) {
					(component as VBaseComponent).dispose();
				} else if (component is DisplayObjectContainer) {
					childrenDispose(component as DisplayObjectContainer);
				}
			}
		}
		
		/**
		 * Задать параметры компоновки
		 * Если геометрия уже расчитана, то вызовется syncLayout
		 * 
		 * @param	data				Хеш
		 * @param	isResetLayout		Сбросить текущие параметры VLayout в дефолт
		 */
		public function setLayout(data:Object, isResetLayout:Boolean = false):void {
			if (data) {
				if (isResetLayout) {
					layout.reset();
				}
				layout.assign(data);
			} else {
				throw new Error('setLayout data is not null');
			}
			
			//inline code syncLayout
			if (parent is VBaseComponent) {
				var p_component:VBaseComponent = parent as VBaseComponent;
				if (isGeometryPhase && p_component.isGeometryPhase) {
					p_component.syncChildLayout(this);
				} else {
					p_component.validContentSize = false;
				}
			}
		}
		
		/**
		 * Синхронизировать компоновку
		 * Следует вызывать если изменение идет через свойства VLayout полученного методом getLayout()
		 * Расчет проивзодится если родитель является VBaseComponent и у него уже расчитана геометрия
		 */
		public function syncLayout():void {
			if (parent is VBaseComponent) {
				var p_component:VBaseComponent = parent as VBaseComponent;
				if (isGeometryPhase && p_component.isGeometryPhase) {
					p_component.syncChildLayout(this);
				} else {
					p_component.validContentSize = false;
				}
			}
		}
		
		protected function syncChildLayout(component:VBaseComponent):void {
			validContentSize = false;
			component.isGeometryPhase = false;
			if (isDependentSize) {
				if (parent is VBaseComponent) {
					(parent as VBaseComponent).syncChildLayout(this);
				}
			}
			if (!component.isGeometryPhase) {
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
					updateW = 0;
					updateH = 0;
					if (parent is VBaseComponent) {
						(parent as VBaseComponent).syncChildLayout(this);
					} else {
						geometryPhase();
					}
				} else {
					updatePhase(true);
				}
			} else if (parent is VBaseComponent) {
				(parent as VBaseComponent).validContentSize = false;
			}
		}
		
		/**
		 * Размер компонента зависит от содержимого либо родительского компонента
		 */
		private function get isDependentSize():Boolean {
			return layout.w == 0 || layout.h == 0 || layout.isWPercent || layout.isHPercent;
		}
		
		/**
		 * Получить компоновку объекта
		 * Если планируется изменение свойств, то в конце нужно вызвать syncLayout
		 * @return
		 */
		public function getLayout():VLayout {
			return layout;
		}
		
		public function get w():uint {
			return $w;
		}
		
		/**
		 * Возвращает заданную в layout абсолютную ширину, если не задана, возвращается contentWidth
		 * 
		 * @return
		 */
		public function get measuredWidth():uint {
			return layout.applyRangeW((!layout.isWPercent && layout.w > 0) ? layout.w : contentWidth);
		}
		
		public function get h():uint {
			return $h;
		}
		
		/**
		 * Возвращает заданную в layout абсолютную высоту, если не задана, возвращается contentHeight
		 * 
		 * @return
		 */
		public function get measuredHeight():uint {
			return layout.applyRangeH((!layout.isHPercent && layout.h > 0) ? layout.h : contentHeight);
		}
		
		public function get contentWidth():uint {
			if (!validContentSize) {
				calcContentSize();
				validContentSize = true;
			}
			return contentW;
		}
		
		public function get contentHeight():uint {
			if (!validContentSize) {
				calcContentSize();
				validContentSize = true;
			}
			return contentH;
		}
		
		/**
		 * Добавить новый дочерний компонент
		 * Групирует addChildAt, set Layout и syncLayout
		 * 
		 * @param	component			Добавляемый компонент
		 * @param	layout				Праметры компоновки
		 * @param	index				Дочерний индекс, если не знадан, то компонент добавляется наверх
		 */
		public function add(component:VBaseComponent, layout:Object = null, index:int = -1):void {
			addChildAt(component, (index >= 0 && index < numChildren) ? index : numChildren);
			if (layout) {
				component.layout.assign(layout);
			}
			if (isGeometryPhase) {
				syncChildLayout(component);
			} else {
				validContentSize = false;
			}
		}
		
		/**
		 * Удаление дочернего компонента
		 * 
		 * @param	child		Удаляеый компонент
		 * @param	isDispose		Также произвести вызов dispose (работает только если component потомок BaseComponent)
		 */
		public function remove(component:VBaseComponent, isDispose:Boolean = true):void {
			if (component && component.parent == this) {
				removeChild(component);
				if (isDispose) {
					component.dispose();
				}
				
				validContentSize = false;
				if (isDependentSize) {
					isGeometryPhase = false;
					if (parent is VBaseComponent) {
						(parent as VBaseComponent).syncChildLayout(this);
					}
					if (!isGeometryPhase) {
						geometryPhase();
					}
				}
			}
		}
		
		/**
		 * Расчитать размер содержимого
		 */
		protected function calcContentSize():void {
			var c_w:uint;
			var c_h:uint;
			for (var i:int = numChildren - 1; i >= 0; i--) {
				var component:VBaseComponent = getChildAt(i) as VBaseComponent;
				if (component) {
					//к ширине и высоте добавляем положительные привязки к границе
					var layout:VLayout = component.getLayout();
					var v:uint = component.measuredWidth;
					if (layout.left > 0) {
						v += layout.left;
					}
					if (layout.right > 0) {
						v += layout.right;
					}
					if (v > c_w) {
						c_w = v;
					}
					
					v = component.measuredHeight;
					if (layout.top > 0) {
						v += layout.top;
					}
					if (layout.bottom > 0) {
						v += layout.bottom;
					}
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
		 * @param	isChangeLayoutSize		Изменить размер компонента заданный в layout (использовать для компонентов !(parent is VBaseComponent)
		 */
		public function setGeometrySize(w:uint, h:uint, isChangeLayoutSize:Boolean):void {
			if (isChangeLayoutSize) {
				layout.w = w;
				layout.isWPercent = false;
				layout.h = h;
				layout.isHPercent = false;
			}
			
			$w = w;
			$h = h;
			isGeometryPhase = true;
			updatePhase();
		}
		
		/**
		 * Фаза геометрии компонента
		 * Производится расчет x, y, w, h
		 */
		public function geometryPhase():void {
			isGeometryPhase = true;
			
			if (parent is VBaseComponent) {
				//ширина родителя
				var p_w:uint = (parent as VBaseComponent).w;
				//высота родителя
				var p_h:uint = (parent as VBaseComponent).h;
			} else {
				p_w = 200;
				p_h = 200;
			}
			
			//расчетная ширина
			var isLeft:Boolean = (layout.left != int.MIN_VALUE);
			var isRight:Boolean = (layout.right != int.MIN_VALUE);
			
			if (!layout.isHCenter && isLeft && isRight) {
				var w:int = p_w - (layout.left + layout.right);
			} else {
				w = layout.isWPercent ? p_w * (layout.w / 100) : layout.w;
			}
			
			if (w <= 0) {
				w = contentWidth;
			}
			//применение граничных значений
			w = layout.applyRangeW(w);
			
			//тоже самое для высоты
			var isTop:Boolean = (layout.top != int.MIN_VALUE);
			var isBottom:Boolean = (layout.bottom != int.MIN_VALUE);
			
			if (!layout.isVCenter && isTop && isBottom) {
				var h:int = p_h - (layout.top + layout.bottom);
			} else {
				h = layout.isHPercent ? p_h * (layout.h / 100) : layout.h;
			}
			
			if (h <= 0) {
				h = contentHeight;
			}
			//применение граничных значений
			h = layout.applyRangeH(h);
			
			$w = w;
			$h = h;
			
			//расчет x
			if (layout.isHCenter) {
				x = ((p_w - w) >> 1) + layout.hCenter;
			} else if (isLeft || isRight) {
				if (isLeft && isRight) {
					x = layout.left;
				} else if (isRight) {
					x = p_w - w - layout.right;
				} else {
					x = layout.left;
				}
			} else {
				x = 0;
			}
			
			//расчет y
			if (layout.isVCenter) {
				y = ((p_h - h) >> 1) + layout.vCenter;
			} else if (isTop || isBottom) {
				if (isTop && isBottom) {
					y = layout.top;
				} else if (isBottom) {
					y = p_h - h - layout.bottom;
				} else {
					y = layout.top;
				}
			} else {
				y = 0;
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
			if (updateW != $w || updateH != $h || force) {
				if (visible) {
					updateW = $w;
					updateH = $h;
					if ($w > 0 && $h > 0) {
						customUpdate();
					}
				} else {
					isWaitUpdatePhase = true;
					if (force) {
						updateW = 0;
						updateH = 0;
					}
				}
			}
		}
		
		/**
		 * Вызвать фазу геометрии у всех дочерних элементов VBaseComponent
		 */
		protected function updateAllChild():void {
			for (var i:int = numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = getChildAt(i);
				if (obj is VBaseComponent) {
					(obj as VBaseComponent).geometryPhase();
				}
			}
		}
		
		/**
		 * Обновление содержимого
		 */
		protected function customUpdate():void {
			updateAllChild();
		}
		
		/**
		 * Показывает/скрыть область занимаюмую компонентом
		 * 
		 * @param	flag		true - показать, false - скрыть
		 * @param	color		цвет заливки
		 * @param	alpha		прозрачность заливки
		 */
		public function showRegion(flag:Boolean = true, color:uint = 0xFF0000, alpha:Number = .5, isFill:Boolean = true):void {
			graphics.clear();
			if (flag) {
				if (isFill) {
					graphics.beginFill(color, alpha);
				} else {
					graphics.lineStyle(1, color, alpha);
				}
				graphics.drawRect(0, 0, w, h);
			}
		}

		/**
		 * Послать VEvent.VARIANCE
		 *
		 * @param variance    		Вариант
		 * @param data
		 */
		public function dispatchVarianceEvent(variance:uint, data:* = null):void {
			var event:VEvent = new VEvent(VEvent.VARIANCE, data);
			event.variance = variance;
			dispatcher.dispatchEvent(event);
		}
	} //end class Component
} //end package Components