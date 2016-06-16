package ui.vbase {
	import flash.events.MouseEvent;

	public class VPager extends VBox {
		private var
			bg:VComponent,
			offset:uint,
			maxCount:uint,
			showCount:uint = 1,
			curIndex:uint,
			onSkinName:String,
			offSkinName:String
			;
		public var showCountLimit:uint;

		/**
		 * Навигационная панель
		 *
		 * @param	onSkinName		Скин активной страницы
		 * @param	offSkinName
		 * @param	gap				Расстояние между кнопками
		 * @param	showCount		Количество видимых страниц
		 * @param	bg				Фон
		 */
		public function VPager(onSkinName:String, offSkinName:String, gap:uint = 6, showCount:uint = 1, bg:VComponent = null) {
			super(null, gap);
			if (bg) {
				this.bg = bg;
				addChild(bg);
			}
			this.onSkinName = onSkinName;
			this.offSkinName = offSkinName;
			this.showCount = showCount > 0 ? showCount : 1;
		}

		/**
		 * Задает параметры навигации
		 *
		 * @param	index				Текущий индекс страницы [0..max-1]
		 * @param	maxCount			Общие количество страниц
		 * @param	showCount			Количество видимых страниц
		 */
		public function setParam(index:uint, maxCount:uint, showCount:uint = 0):void {
			if (maxCount == 0) {
				maxCount = 1;
			}
			if (showCount > 0) {
				this.showCount = (showCountLimit > 0 && showCount > showCountLimit) ? showCountLimit : showCount;
			}

			this.maxCount = maxCount;
			var newCount:uint = this.showCount < maxCount ? this.showCount : maxCount; //количетсво кнопок
			var curCount:uint = list.length;
			if (newCount != curCount) {
				//сделаем активной текущую кнопку
				if (list.length > 0) {
					var bt:VButton = list[curIndex - offset] as VButton;
					bt.mouseEnabled = true;
					bt.data = null;
				}

				if (newCount > curCount) { //добавить кнопок
					for (var i:int = newCount - curCount; i >= 1; i--) {
						bt = VButton.createEmbed(offSkinName);
						addChild(bt);
						list.push(bt);
						bt.addClickListener(onClickHandler);
					}
				} else { //удалить кнопки
					for (i = curCount - newCount; i >= 1; i--) {
						var j:uint = list.length - 1;
						bt = list[j] as VButton;
						removeChild(bt);
						list.splice(j, 1);
						bt.dispose();
					}
				}

				curIndex = (index >= maxCount) ? maxCount - 1 : index;
				calcOffset();
				(list[curIndex - offset] as VButton).data = null;
				fullUpdate();

				syncContentSize(true);
			} else {
				this.index = index;
			}
		}
		/**
		 * Расчет стартового смещения
		 *
		 * @return		true - смещение изменилось, false - не изменилось
		 */
		private function calcOffset():Boolean {
			if (maxCount > showCount) {
				var newOffset:int = curIndex - (showCount >> 1);
				if (newOffset < 0) {
					newOffset = 0;
				} else if (newOffset > maxCount - showCount) {
					newOffset = maxCount - showCount;
				}
			} else {
				newOffset = 0;
			}
			var result:Boolean = (newOffset != offset);
			if (result) {
				offset = newOffset;
			}
			return result;
		}

		/**
		 * Индекс текущей страницы [0..max-1]
		 */
		public function set index(value:uint):void {
			if (value >= maxCount) {
				value = maxCount - 1;
			}
			if (value == curIndex) {
				return;
			}

			var bt:VButton = list[curIndex - offset] as VButton;
			bt.mouseEnabled = true;

			curIndex = value;
			//если изменился offset вызываем полное обновление кнопок, иначе меняем только 2 кнопки
			if (calcOffset()) {
				fullUpdate();
			} else {
				SkinManager.applyEmbed(bt.skin as VSkin, offSkinName);
				bt = list[curIndex - offset] as VButton;
				bt.mouseEnabled = false;
				SkinManager.applyEmbed(bt.skin as VSkin, onSkinName);
			}
		}

		public function get index():uint {
			return curIndex;
		}

		public function get max():uint {
			return maxCount;
		}

		private function fullUpdate():void {
			for (var i:int = list.length - 1; i >= 0; i--) {
				var bt:VButton = list[i] as VButton;
				var j:uint = offset + i;
				if (bt) {
					var isSelect:Boolean = (curIndex == j);
					if (isSelect) {
						bt.mouseEnabled = false;
					}
					if (bt.data !== j) {
						bt.data = j;
						SkinManager.applyEmbed(bt.skin as VSkin, isSelect ? onSkinName : offSkinName);
					}
				}
			}
		}

		/**
		 * Обработчик клика по page-кнопкам
		 *
		 * @param	event			Объект события MouseEvent.CLICK
		 */
		private function onClickHandler(event:MouseEvent):void {
			index = (event.currentTarget as VButton).data as uint;
			dispatcher.dispatchEvent(new VEvent(VEvent.SELECT, curIndex));
		}

		override protected function customUpdate():void {
			if (bg) {
				bg.geometryPhase();
			}
			super.customUpdate();
		}

	} //end class
}