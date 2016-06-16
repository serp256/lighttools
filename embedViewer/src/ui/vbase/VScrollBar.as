package ui.vbase {
	import flash.events.Event;
	import flash.events.MouseEvent;

	public class VScrollBar extends VComponent {
		public static const
			HORIZONTAL:uint = 1,
			TRACK_DOWN:uint = 2,
			WHEEL:uint = 4
			;
		private var
			pageSize:uint,
			minShift:uint = 1,
			max:uint,
			cur:uint,

			thumbStartPos:uint,
			thumbDeltaPos:uint,
			isThumbMove:Boolean,
			thumbStagePos:Number,
			thumbMovePos:uint,

			track:VComponent,
			thumb:VComponent,
			upBt:VButton,
			downBt:VButton
			;

		public function VScrollBar(track:VComponent, thumb:VComponent, mode:uint = 0) {
			this.mode = mode;
			if ((mode & TRACK_DOWN) != 0) {
				track.addListener(MouseEvent.MOUSE_DOWN, onTrackDown);
			} else {
				track.addListener(MouseEvent.CLICK, onTrackClick);
			}
			this.track = track;
			this.thumb = thumb;
			thumb.addListener(MouseEvent.MOUSE_DOWN, onThumbDown);
			if ((mode & WHEEL) != 0) {
				addListener(MouseEvent.MOUSE_WHEEL, onWheel);
			}

			addListener(Event.REMOVED_FROM_STAGE, onThumbOut);
		}

		public function assignButton(upBt:VButton, downBt:VButton, shift:uint = 1):void {
			this.upBt = upBt;
			upBt.addClickListener(onTrackClick, shift > 0 ? shift : 1);
			this.downBt = downBt;
			downBt.addClickListener(onTrackClick);
		}

		/**
		 * Установить свойства скрола
		 * 
		 * @param	pageSize		Сколько позиций вмещается на странице
		 * @param	max				Максимальная позиция, интервал [1..max]
		 * @param	cur				Текущая позиция
		 * @param	minShift		Минимальное смещение
		 */
		public function setEnv(pageSize:uint, max:uint, cur:uint = 0, minShift:uint = 1):void {
			if (pageSize > max) {
				pageSize = max;
			}
			if (pageSize == max) {
				cur = 0;
			}
			this.pageSize = pageSize;
			this.max = max;
			this.minShift = (minShift > 0) ? minShift : 1;
			
			this.cur = cur > max - pageSize ? max - pageSize : cur;
			thumb.mouseEnabled = track.mouseEnabled = max > pageSize;

			if (isGeometryPhase) {
				updatePhase(true);
			}
		}

		public function changeButtonSize(value:uint):void {
			if (value > 0 && upBt) {
				upBt.data = value;
			}
		}
		
		public function get value():Number {
			return cur;
		}
		
		public function set value(value:Number):void {
			changePosition(value, false);
		}

		public function getMax():uint {
			return max;
		}

		public function getPageSize():uint {
			return pageSize;
		}

		//Обработчик клика по треку и кнопкам up, down
		private function onTrackClick(event:MouseEvent):void {
			if (max > pageSize) {
				if (event.currentTarget == upBt) {
					changePosition(cur - uint(upBt.data));
				} else if (event.currentTarget == downBt) {
					changePosition(cur + uint(upBt.data));
				} else {
					changePosition(cur + (cur < mouseCur ? 1 : -1) * pageSize);
				}
			}
		}

		private function get mouseCur():Number {
			return ((((mode & HORIZONTAL) == 0 ? mouseY : mouseX) - thumbStartPos) / thumbDeltaPos) * (max - pageSize);
		}

		private function onTrackDown(event:MouseEvent):void {
			changePosition(mouseCur);
			onThumbDown(event);
			if (isThumbMove) {
				onThumbMove(event);
			}
		}

		private function onWheel(event:MouseEvent):void {
			if (max > pageSize) {
				changePosition(cur + uint(upBt.data) * ((event.delta < 0) ? 1 : -1));
			}
		}

		//обработчик нажатия по ползунку
		private function onThumbDown(event:MouseEvent):void {
			if (max > pageSize) {
				thumbStagePos = (mode & HORIZONTAL) != 0 ? event.stageX : event.stageY;
				thumbMovePos = cur;

				if (!isThumbMove) {
					isThumbMove = true;
					stage.mouseChildren = false;
					stage.addEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
					stage.addEventListener(MouseEvent.MOUSE_UP, onThumbOut);
				}
			}
		}
		
		//перемещение ползунка
		private function onThumbMove(event:MouseEvent):void {
			changePosition(Math.round(
				(thumbMovePos + (((mode & HORIZONTAL) != 0 ? event.stageX : event.stageY) - thumbStagePos) * ((max - pageSize) / thumbDeltaPos)
			) / minShift) * minShift);
		}
		
		//отпустили ползунок
		private function onThumbOut(event:Event):void {
			if (isThumbMove) {
				isThumbMove = false;
				stage.mouseChildren = true;
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
				stage.removeEventListener(MouseEvent.MOUSE_UP, onThumbOut);
			}
		}
		
		/**
		 * Задает новое текущее значение
		 * 
		 * @param	value		Устанавливаемая величина
		 * @param	isEvent		Нужно ли отправлять событие об изменении
		 */
		private function changePosition(value:int, isEvent:Boolean = true):void {
			if (value < 0) {
				value = 0;
			} else if (value > max - pageSize) {
				value = max - pageSize;
			}
			if (cur != value) {
				cur = value;
				syncUI();
				if (isEvent) {
					dispatcher.dispatchEvent(new VEvent(VEvent.SCROLL, value));
				}
			}
		}

		protected function get thumbPos():Number {
			var v:Number = thumbStartPos;
			if (max > pageSize) {
				v += Math.round(thumbDeltaPos * (cur / (max - pageSize)));
			}
			return v;
		}

		protected function syncUI():void {
			if (isGeometryPhase) {
				if ((mode & HORIZONTAL) != 0) {
					thumb.x = thumbPos;
				} else {
					thumb.y = thumbPos;
				}
			}
			if (upBt) {
				upBt.disabled = (cur <= 0);
				downBt.disabled = (cur >= max - pageSize);
			}
		}
		
		override protected function customUpdate():void {
			super.customUpdate();

			var isVertical:Boolean = (mode & HORIZONTAL) == 0;
			thumbStartPos = isVertical ? thumb.y : thumb.x;
			if (max > pageSize) {
				if (isVertical) {
					var v:uint = thumb.applyRangeH(Math.round((pageSize / max) * thumb.h));
					thumbDeltaPos = thumb.h - v;
					if (v != thumb.h) {
						thumb.setGeometrySize(thumb.w, v, false);
					}
				} else {
					v = thumb.applyRangeW(Math.round((pageSize / max) * thumb.w));
					thumbDeltaPos = thumb.w - v;
					if (v != thumb.w) {
						thumb.setGeometrySize(v, thumb.h, false);
					}
				}
			} else {
				thumbDeltaPos = 0;
			}

			syncUI();
		}

		override public function dispose():void {
			onThumbOut(null);
			super.dispose();
		}

	} //end class
}