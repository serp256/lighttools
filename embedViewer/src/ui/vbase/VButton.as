package ui.vbase {
	import flash.events.EventDispatcher;
	import flash.events.MouseEvent;
	import flash.geom.ColorTransform;

	public class VButton extends VComponent {
		public static const //состояния
			UP:uint = 0,
			OVER:uint = 1,
			DOWN:uint = 2,
			DISABLED:uint = 3
			;
		private var
			downFlag:Boolean,
			state:uint = UP
			;
		public var
			skin:VComponent,
			icon:VComponent,
			changeStateFunc:Function = defaultButtonChangeState,
			variance:uint,
			data:Object
			;

		public function VButton() {
			mouseChildren = false;
			buttonMode = true;
			CONFIG::debug {
				useToolSolid();
			}
			
			addListener(MouseEvent.ROLL_OVER, onMouse);
			addListener(MouseEvent.ROLL_OUT, onMouse);
			addListener(MouseEvent.MOUSE_DOWN, onMouse);
			addListener(MouseEvent.MOUSE_UP, onMouse);
		}
		
		/**
		 * Задать фон
		 * 
		 * @param	value		VBaseComponent	
		 * @param	layout		Параметры компоновки
		 */
		public function setSkin(value:VComponent, layout:Object = null):void {
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
		public function setIcon(value:VComponent, layout:Object = null):void {
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
		
		private function onMouse(event:MouseEvent):void {
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
					changeStateFunc(this, newState);
				}
				state = newState;
			}
		}

		override protected function calcContentSize():void {
			if (skin) {
				contentW = skin.measuredWidth;
				contentH = skin.measuredHeight;
			} else {
				super.calcContentSize();
			}
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
		 * Эмулирует клик по кнопке
		 */
		public function click():void {
			dispatchEvent(new MouseEvent(MouseEvent.CLICK));
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
			addListener(MouseEvent.CLICK, onVariance);
		}
		
		protected function onVariance(event:MouseEvent = null):void {
			var newEvent:VEvent = new VEvent(VEvent.VARIANCE, data);
			newEvent.variance = variance;
			dispatcher.dispatchEvent(newEvent);
		}


		override public function set mouseEnabled(enabled:Boolean):void {
			if (!enabled) {
				if (state != UP && state != DISABLED) {
					changeState(UP);
				}
			}
			super.mouseEnabled = enabled;
		}

		private static const
			downTransform:ColorTransform = new ColorTransform(0.9, 0.9, 0.9),
			upTransform:ColorTransform = new ColorTransform()
			;
		public static function defaultButtonChangeState(bt:VButton, newState:uint):void {
			if (newState == VButton.DISABLED) {
				bt.filters = VSkin.GREY_FILTER;
			} else {
				bt.filters = null;
				if (newState == VButton.DOWN) {
					bt.transform.colorTransform = downTransform;
				} else {
					bt.transform.colorTransform = upTransform;
					if (newState == VButton.OVER) {
						bt.filters = VSkin.CONTRAST_FILTER;
					}
				}
			}
		}

		/*
		public static function mcButtonChangeState(bt:VButton, newState:uint, isPlay:Boolean = false):void {
			if (bt.skin is VSkin) {
				var mc:MovieClip = (bt.skin as VSkin).content as MovieClip;
			}
			if (!mc) {
				return;
			}
			if (bt.state == VButton.DISABLED) {
				bt.filters = null;
			}
			switch (newState) {
				case VButton.DOWN:
					frame = '_down';
					break;

				case VButton.OVER:
					frame = '_over';
					break;

				case VButton.DISABLED:
					isPlay = false;
					var frame:String = '_disable';
					var flag:Boolean;
					for each (var frameLabel:FrameLabel in mc.currentLabels) {
						if (frameLabel.name == frame) {
							flag = true;
							break;
						}
					}
					if (!flag) { //если нет такого кадра, то используем фильтр и _up
						bt.filters = [VSkin.GREY_FILTER];
					} else {
						break;
					}

				default:
					frame = '_up';
			}
			if (isPlay) {
				mc.gotoAndPlay(frame);
			} else {
				mc.gotoAndStop(frame);
			}
		}
		*/

		/**
		 * Создать кнопку
		 * Универсальный метод
		 *
		 * @param    skin                Скин
		 * @param    skinLayout          Layout-скина
		 * @param    icon                Иконка
		 * @param    iconLayout          Layout-иконки
		 * @param    changeStateFunc
		 * @return
		 */
		public static function create(skin:VComponent, skinLayout:Object = null, icon:VComponent = null, iconLayout:Object = null, changeStateFunc:Function = null):VButton {
			var bt:VButton = new VButton();
			if (skin) {
				bt.setSkin(skin, skinLayout);
			}
			if (icon) {
				bt.setIcon(icon, iconLayout);
			}
			if (changeStateFunc != null) {
				bt.changeStateFunc = changeStateFunc;
			}
			return bt;
		}

		/**
		 * Создать кнопку на базе embed-скина
		 * Кнопка принимает размер скина
		 *
		 * @param    skinName            Имя скина
		 * @param    skinMode            Режим скина
		 * @param    icon                Иконка
		 * @param    iconLayout          Layout-иконки
		 * @param    changeStateFunc
		 * @return
		 */
		public static function createEmbed(skinName:String, skinMode:uint = 0, icon:VComponent = null, iconLayout:Object = null, changeStateFunc:Function = null):VButton {
			var skin:VSkin = SkinManager.getEmbed(skinName, skinMode);
			var bt:VButton = new VButton();
			bt.setSize(skin.measuredWidth, skin.measuredHeight);
			bt.setSkin(skin);
			skin.stretch();
			if (icon) {
				bt.setIcon(icon, iconLayout);
			}
			if (changeStateFunc != null) {
				bt.changeStateFunc = changeStateFunc;
			}
			return bt;
		}

	} //end class
}