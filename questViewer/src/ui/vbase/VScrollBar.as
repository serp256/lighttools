package ui.vbase {
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	public class VScrollBar extends VBox {
		private var pageSize:Number = 0;
		private var pageScrollSize:Number = 0;
		private var lineScrollSize:Number = 1;
		private var maxPosition:Number = 0;
		private var curPosition:Number = -1;
		
		private var thumbY:Number;
		private var startPos:Number;
		
		private var upButton:VButton;
		private var downButton:VButton;
		private var thumbSkin:VSkin;
		private var trackSkin:VSkin;
		
		/**
		 * VScrollBar
		 * 
		 * @param	upButton
		 * @param	downButton
		 * @param	trackSkin
		 * @param	thumbSkin			Должно быть задано центрирование и минимальный размер
		 */
		public function VScrollBar(upButton:VButton, downButton:VButton, trackSkin:VSkin, thumbSkin:VSkin):void {
			super(new <VBaseComponent>[upButton, trackSkin, downButton], true, 0);
			mouseEnabled = false;
			
			this.upButton = upButton;
			this.downButton = downButton;
			this.thumbSkin = thumbSkin;
			this.trackSkin = trackSkin;
			
			addListener(MouseEvent.CLICK, onScrollPressHandler, upButton);
			addListener(MouseEvent.CLICK, onScrollPressHandler, downButton);
			addListener(MouseEvent.MOUSE_DOWN, onScrollPressHandler, trackSkin);
			
			addChild(thumbSkin);
			thumbSkin.buttonMode = true;
			addListener(MouseEvent.MOUSE_DOWN, onThumbHandler, thumbSkin);
		}
		
		/**
		 * Установить свойства скрола
		 * 
		 * @param	pageSize				Сколько позиций вмещается на странице
		 * @param	maxPosition				Максимальная позиция, интервал [0..maxPosition]
		 * @param	curPosition				Текущая позиция
		 * @param	pageScrollSize			Смещение при нажатии по треку
		 * @param	lineScrollSize			Смещение при нажатии по кнопкам
		 */
		public function setProperties(pageSize:Number, maxPosition:Number, curPosition:Number = 0, pageScrollSize:Number = 0, lineScrollSize:Number = 1):void {
			if (maxPosition < 0) {
				throw new Error('VScrollBar: maxPosition < 0');
			}
			if (pageSize < 0) {
				throw new Error('VScrollBar: pageSize < 0');
			}
			
			if (pageSize > maxPosition) {
				pageSize = maxPosition;
			}
			this.pageSize = pageSize;
			this.maxPosition = maxPosition;
			this.pageScrollSize = (pageScrollSize > 0) ? pageScrollSize : 0;
			this.lineScrollSize = (lineScrollSize > 0) ? lineScrollSize : 1;
			
			this.curPosition = curPosition;
			thumbSkin.mouseEnabled = trackSkin.mouseEnabled = maxPosition > pageSize;
			
			if (isGeometryPhase) {
				updatePhase(true);
			}
		}
		
		public function get scrollPosition():Number {
			return curPosition;
		}
		
		public function set scrollPosition(value:Number):void {
			setScrollPosition(value, false);
		}
		
		/**
		 * Обработчик клика по кнопкам, бегунку и треку
		 * 
		 * @param	event	Объект события MouseEvent.MOUSE_DOWN
		 */
		private function onScrollPressHandler(event:MouseEvent):void {
			event.stopImmediatePropagation();
			
			if (maxPosition > pageSize) {
				if (event.currentTarget == upButton) {
					setScrollPosition(curPosition - lineScrollSize, true);
				} else if (event.currentTarget == downButton) {
					setScrollPosition(curPosition + lineScrollSize, true);
				} else {
					var mousePosition:Number = ((trackSkin.mouseY) / (trackSkin.h - thumbSkin.h)) * (maxPosition - pageSize);
					if (pageScrollSize > 0) {
						setScrollPosition(curPosition + (curPosition < mousePosition ? 1 : -1) * pageScrollSize, true);
					} else {
						setScrollPosition(mousePosition, true);
					}
				}
			}
		}
		
		//обработчик нажатия по ползунку
		private function onThumbHandler(event:MouseEvent):void {
			if (maxPosition > pageSize) {
				thumbY = event.stageY;
				startPos = curPosition;
				if (stage) {
					//mouseChildren = false;
					stage.addEventListener(MouseEvent.MOUSE_MOVE, onThumbDragHandler, false, 0, true);
					stage.addEventListener(MouseEvent.MOUSE_UP, onThumbReleaseHandler, false, 0, true);
					stage.addEventListener(Event.MOUSE_LEAVE, onThumbReleaseHandler, false, 0, true);
				}
			}
		}
		
		//пермещение ползунка
		private function onThumbDragHandler(event:MouseEvent):void {
			setScrollPosition(Math.round(
				(startPos + (event.stageY - thumbY) * ((maxPosition - pageSize) / (trackSkin.h - thumbSkin.h))
			) / lineScrollSize) * lineScrollSize, true);
		}
		
		//отпустили ползунок
		private function onThumbReleaseHandler(event:MouseEvent):void {
			//mouseChildren = true;
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onThumbDragHandler);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onThumbReleaseHandler);
			stage.removeEventListener(Event.MOUSE_LEAVE, onThumbReleaseHandler);
		}
		
		/**
		 * Задает новое текущее значение
		 * 
		 * @param	newPos			Устанавливаемая величина
		 * @param	fireEvent		Нужно ли отправлять событие об изменении
		 */
		private function setScrollPosition(newPos:Number, fireEvent:Boolean):void {
			if (newPos < 0) {
				newPos = 0;
			} else if (newPos > maxPosition - pageSize) {
				newPos = maxPosition - pageSize;
			}
			if (curPosition != newPos) {
				curPosition = newPos;
				
				if (isGeometryPhase) {
					var y:Number = trackSkin.y;
					if (maxPosition > pageSize) {
						y += (trackSkin.h - thumbSkin.h) * (newPos / (maxPosition - pageSize));
					}
					thumbSkin.y = y;
				}
				upButton.disabled = (newPos <= 0);
				downButton.disabled = (newPos >= maxPosition - pageSize);
				
				if (fireEvent) {
					dispatchEvent(new VEvent(VEvent.SCROLL, newPos));
				}
			}
		}
		
		override protected function customUpdate():void {
			super.customUpdate();
			
			var layout:VLayout = thumbSkin.getLayout();
			layout.w = trackSkin.w;
			if (maxPosition > pageSize) {
				var h:uint = Math.round((pageSize / maxPosition) * trackSkin.h);
				if (h < layout.minH) {
					h = layout.minH;
				}
			} else {
				h = trackSkin.h;
			}
			layout.h = h;
			thumbSkin.geometryPhase();
			
			var oldPosition:Number = curPosition;
			curPosition = -1;
			setScrollPosition(oldPosition, false);
		}
		
	} //end class
}