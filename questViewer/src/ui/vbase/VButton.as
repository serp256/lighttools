package ui.vbase {
	import flash.events.EventDispatcher;
	import flash.events.MouseEvent;


	public class VButton extends VBaseComponent {
		//состояния
		public static const UP:uint = 0;
		public static const OVER:uint = 1;
		public static const DOWN:uint = 2;
		public static const DISABLED:uint = 3;
		
		private var downFlag:Boolean = false;
		private var state:uint = UP;
		
		public var skin:VBaseComponent;
		public var icon:VBaseComponent;
		public var changeStateFunc:Function;
		public var variance:uint;
		public var data:Object;
		//public var sound:String;
		
		public function VButton():void {
			mouseChildren = false;
			buttonMode = true;
			
			/*addListener(MouseEvent.ROLL_OVER, onMouseHandler);
			addListener(MouseEvent.ROLL_OUT, onMouseHandler);
			addListener(MouseEvent.MOUSE_DOWN, onMouseHandler);
			addListener(MouseEvent.MOUSE_UP, onMouseHandler); */
		}
		
		/**
		 * Задать фон
		 * 
		 * @param	value		VBaseComponent	
		 * @param	layout		Параметры компоновки
		 */
		public function setSkin(value:VBaseComponent, layout:Object = null):void {
			if (skin) {
				remove(skin);
			}
			skin = value;
			if (value) {
				add(value, layout, 0);
			}
		}
		
		/**
		 * Задать иконку
		 * 
		 * @param	value		VBaseComponent
		 * @param	layout		Параметры компоновки
		 */
		public function setIcon(value:VBaseComponent, layout:Object = null):void {
			if (icon) {
				remove(icon);
			}
			icon = value;
			if (value) {
				add(value, layout);
			}
		}
		
		public function set disabled(value:Boolean):void {
			if ((state == DISABLED) != value) {
				changeState(value ? DISABLED : UP);
				mouseEnabled = !value;
			}
		}
		
		public function get disabled():Boolean {
			return (state == DISABLED);
		}
		
		private function onMouseHandler(event:MouseEvent):void {
			if (state == DISABLED) {
				return;
			}
			switch (event.type) {
				case MouseEvent.ROLL_OVER:
					if (downFlag && !event.buttonDown) {
						downFlag = false;
					}
					var newState:uint = downFlag ? DOWN : OVER;
					break;
					
				case MouseEvent.MOUSE_DOWN:
					downFlag = true;
					newState = DOWN;
					break;
					
				case MouseEvent.MOUSE_UP:
					newState = OVER;
					break;
					
				default:
					newState = UP;
			} //end switch
			
			changeState(newState);
		}
		
		private function changeState(newState:uint):void {
			if (newState != state) {
				if (changeStateFunc != null) {
					changeStateFunc(this, newState, state);
				}
				state = newState;
			}
		}
		
		/**
		 * Если не задана дефолт ширина, то будет отдана дефолтная ширина скина
		 */
		override public function get contentWidth():uint {
			if (skin) {
				return skin.measuredWidth;
			}
			return super.contentWidth;
		}
		
		/**
		 * Если не задана дефолт высота, то будет отдана дефолтная высота скина
		 */
		override public function get contentHeight():uint {
			if (skin) {
				return skin.measuredHeight;
			}
			return super.contentHeight;
		}
		
		override public function dispose():void {
			changeStateFunc = null;
			super.dispose();
		}
		
		/**
		 * Задает слушателя для события MouseEvent.CLICK
		 * 
		 * @param	func		Функция обработчик
		 * @param	data		Задает значение данных
		 */
		public function addClickListener(func:Function, data:Object = null):void {
			if (data != null) {
				this.data = data;
			}
			addListener(MouseEvent.CLICK, func);
		}
		
		/**
		 * Эмулирует клик по кнопку
		 */
		public function click():void {
			dispatcher.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		}
		
		/**
		 * Добавить вариантное событие
		 * 
		 * @param	dispatcher		Определеяет значение свойства dispatcher
		 * @param	variance		Тип варианта
		 * @param	data			Задает значение данных (свойство data), только если data != null
		 */
		public function addVarianceListener(dispatcher:EventDispatcher, variance:uint, data:Object = null):void {
			this.dispatcher = dispatcher;
			this.variance = variance;
			if (data != null) {
				this.data = data;
			}
			addListener(MouseEvent.CLICK, onVarianceHandler);
		}
		
		private function onVarianceHandler(event:MouseEvent):void {
			var e:VEvent = new VEvent(VEvent.VARIANCE, data);
			e.variance = variance;
			dispatcher.dispatchEvent(e);
		}
		
	} //end class
}