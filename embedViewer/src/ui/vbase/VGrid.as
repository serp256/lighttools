package ui.vbase {

	public class VGrid extends VComponent {
		public static const
			/**
			 * Режим фильтрации данных
			 * Будет работать только если данные расширяют класс ui.vbase.VOGridFilterItem
			 */
			FILTER_MODE:uint = 1,
			/**
			 * Растягивать по горизонтали
			 */
			H_STRETCH:uint = 2,
			/**
			 * Растягивать по вертикали
			 */
			V_STRETCH:uint = 4,
			/**
			 * Данные могут показываться с произвольного индекса
			 * Поведение по умолчанию - выравнивание относительно количества рендеров
			 */
			FLOAT_INDEX:uint = 8,
			/**
			 * Если не хватает данных для отображения в ренедерер будет передаваться null
			 */
			USE_NULL_DATA:uint = 16,
			/**
			 * Не выравнивать рендереры по центру
			 */
			USE_TOP_LEFT:uint = 32,
			/**
			 * Индекс не может быть больше dpLength - _maxRenderer
			 */
			USE_END_LIMIT:uint = 64,
			/**
			 * При расчете размера содержимого будут учитываться только видимые рендереры
			 * Производить центрирование рендероров из расчета видимых рендереров
			 */
			USE_VISIBLE_CALC_LAYOUT:uint = 128,
			/**
			 * Режим одиночного выбора
			 * VGrid начинает слушать событие VEvent.SELECT, которое должно идти со стороны рендерера в случае смены выбора.
			 * В этом событие variance долэен содержать dataIndex.
			 * Чтобы визуально отображать выбор нужно переопределить метод VRenderer.setSelected(flag:Boolean).
			 * Как правило смена выбора производится через клик,
			 * Если нужна дополнительная логика при смене выбора нужно добавить обработчик VGrid.addListener(VEvent.SELECT, handler).
			 */
			SELECTED_MODE:uint = 256,
			/**
			 * Можно отменять текущий выбор (только если определен SELECTED_MODE)
			 */
			USE_INVERT_SELECT:uint = 512
			;
		protected static const
			CALC_H_COUNT:uint = 32768,
			CALC_V_COUNT:uint = 65536
			;
		public const renderList:Vector.<VRenderer> = new Vector.<VRenderer>();
		public var
			emptyFactory:Function,
			control:GridControl
			;
		private var
			dataProvider:Array,
			_hGap:uint,
			_vGap:uint,
			_hCount:uint,
			_vCount:uint,
			_maxRenderer:uint,
			dpIndex:uint,			//Индекс первого элемента
			dpLength:uint,			//Количество элементов в списке данных
			rendererFactory:Object,
			emptyComponent:VComponent,
			selectDataIndex:uint = uint.MAX_VALUE
			;
		
		/**
		 * Сетка панель
		 * 
		 * @param	hCount					Количество столбцов (x)
		 * @param	vCount					Количество рядов (y)
		 * @param	rendererClassOrFactory  Класс рендерера || Функция возвращающая новый рендерер
		 * @param	dp						Список данных
		 * @param	hGap					Горизонтальный пробел
		 * @param	vGap					Вертикальный пробел
		 * @param	mode					Режимы
		 * @param	index					Индекс первого элемента
		 */
		public function VGrid(hCount:uint, vCount:uint, rendererClassOrFactory:Object, dp:Array = null, hGap:uint = 0, vGap:uint = 0, mode:uint = 0, index:uint = 0) {
			if (hCount == 0) {
				mode |= CALC_H_COUNT;
				hCount = 1;
			}
			if (vCount == 0) {
				mode |= CALC_V_COUNT;
				vCount = 1;
			}

			_hCount = hCount;
			_vCount = vCount;
			_maxRenderer = vCount * hCount;
			_hGap = hGap;
			_vGap = vGap;
			this.mode = mode;
			if ((mode & SELECTED_MODE) != 0) {
				addListener(VEvent.SELECT, onSelect);
			}
			rendererFactory = rendererClassOrFactory;
			renderList.push(createRenderer());

			if (dp) {
				dataProvider = dp;
				sync(index, false); //технически еще нельзя подписаться на эвент
			}
		}

		/**
		 * Изменить количество визуализаторов
		 * 
		 * @param	hCount		Количество столбцов
		 * @param	vCount		Количестов рядов
		 * @param	newDp		Новый список данных (опционально)
		 * @param	index		Начальный индекс (опционально, если задано newDp)
		 * @param	isSyncSize
		 */
		public function changeRendererCount(hCount:uint, vCount:uint, newDp:Array = null, index:uint = 0, isSyncSize:Boolean = true):void {
			if (hCount == 0) {
				hCount = 1;
			}
			if (vCount == 0) {
				vCount = 1;
			}

			var isChange:Boolean = hCount != _hCount || vCount != _vCount;
			if (isChange) {
				_maxRenderer = hCount * vCount;
				_hCount = hCount;
				_vCount = vCount;
				while (renderList.length > _maxRenderer) {
					super.remove(renderList.pop());
				}
			}

			if (newDp) {
				setDataProvider(newDp, index);
			} else if (isChange) {
				sync();
			}
			if (isChange && isSyncSize) {
				syncContentSize(true);
			}
		}

		private function createRenderer():VRenderer {
			var renderer:VRenderer = rendererFactory is Function ? (rendererFactory as Function)() : new (rendererFactory as Class)();
			if (renderer.layoutW == 0) {
				renderer.layoutW = 100;
			}
			if (renderer.layoutH == 0) {
				renderer.layoutH = 100;
			}
			renderer.useRuledLayout();
			renderer.dispatcher = this;
			return renderer;
		}
		
		override protected function calcContentSize():void {
			var isCalc:Boolean = (mode & USE_VISIBLE_CALC_LAYOUT) != 0;
			if (isCalc) {
				var visibleCount:uint = getRendererVisibleCount();
				if (visibleCount == 0) {
					visibleCount = 1;
				}
				var count:uint = visibleCount <= _hCount ? visibleCount : _hCount;
			} else {
				count = _hCount;
			}

			contentW = renderList[0].layoutW * count;
			if (count > 1) {
				contentW += _hGap * (count - 1);
			}

			if (isCalc) {
				count = Math.ceil(visibleCount / _hCount);
				if (count > _vCount) {
					count = _vCount;
				}
			} else {
				count = _vCount;
			}
			contentH = renderList[0].layoutH * count;
			if (count > 1) {
				contentH += _vGap * (count - 1);
			}
		}
		
		public function get vGap():uint {
			return _vGap;
		}
		
		public function set vGap(value:uint):void {
			_vGap = value;
			syncContentSize(true);
		}
		
		public function get hGap():uint {
			return _hGap;
		}
		
		public function set hGap(value:uint):void {
			_hGap = value;
			syncContentSize(true);
		}
		
		public function get hCount():uint {
			return _hCount;
		}

		public function get vCount():uint {
			return _vCount;
		}

		public function get maxRenderer():uint {
			return _maxRenderer;
		}
		
		public function setDataProvider(dp:Array, index:uint = 0):void {
			dataProvider = dp;
			sync(index);
		}
		
		private function applyIndex():void {
			if (dpIndex > 0) {
				if (dpLength <= _maxRenderer) {
					dpIndex = 0;
				} else {
					if (dpIndex >= dpLength) {
						dpIndex = dpLength - 1;	
					}
					//выравнивание относительно страниц
					if ((mode & FLOAT_INDEX) == 0) {
						dpIndex = uint(dpIndex / _maxRenderer) * _maxRenderer;
					}
					if ((mode & USE_END_LIMIT) != 0 && dpIndex > dpLength - _maxRenderer) {
						dpIndex = dpLength - _maxRenderer;
					}
				}
			}
		}

		protected function get useFilterItem():Boolean {
			return ((mode & FILTER_MODE) != 0) && dataProvider && dataProvider.length > 0 && dataProvider[0] is VOGridFilterItem;
		}

		public function sync(index:int = -1, isEventChange:Boolean = true):void {
			if (index >= 0) {
				dpIndex = index;
			}
			if (dataProvider) {
				if (useFilterItem) {
					dpLength = 0;
					for each (var item:VOGridFilterItem in dataProvider) {
						if (item.isUse) {
							dpLength++;
						}
					}
				} else {
					dpLength = dataProvider.length;
				}
			} else {
				dpLength = 0;
			}
			applyIndex();
			updateRendererData();

			if (dpLength == 0) {
				if (!emptyComponent && emptyFactory != null) {
					emptyComponent = emptyFactory();
					addChild(emptyComponent);
					emptyComponent.geometryPhase();
				}
			} else if (emptyComponent) {
				super.remove(emptyComponent);
				emptyComponent = null;
			}

			if (isEventChange) {
				dispatchEvent(new VEvent(VEvent.CHANGE, dpIndex));
			}
		}
		
		public function getDataProvider():Array {
			return dataProvider;
		}
		
		public function get length():uint {
			return dpLength;
		}
		
		public function get index():uint {
			return dpIndex;
		}
		
		public function set index(value:uint):void {
			if (dataProvider) {
				var old:uint = dpIndex;
				dpIndex = value;
				applyIndex();
				if (old != dpIndex) {
					updateRendererData();
					dispatchEvent(new VEvent(VEvent.CHANGE, dpIndex));
				}
			}
		}

		public function checkShowIndex(value:uint):Boolean {
			return value >= dpIndex && value < dpIndex + _maxRenderer;
		}
		
		public function clear():void {
			dataProvider = null;
			dpLength = 0;
			dpIndex = 0;
			updateRendererData();
		}

		public function getIndexData():Object {
			return dpIndex < dpLength ? dataProvider[dpIndex] : null;
		}

		public function getData(index:uint):Object {
			return index < dpLength ? dataProvider[index] : null;
		}

		public function getSelectData():Object {
			return selectDataIndex < dpLength ? dataProvider[selectDataIndex] : null;
		}

		public function getSelectIndex():uint {
			return selectDataIndex;
		}

		protected function getFilterData(index:uint):Object {
			if (index >= dpLength) {
				return null;
			}
			var i:uint = 0;
			for each (var item:VOGridFilterItem in dataProvider) {
				if (item.isUse) {
					if (index == i) {
						return item;
					} else {
						i++;
					}
				}
			}
			return null;
		}
		
		/**
		 * Полное обновление данных
		 */
		protected function updateRendererData():void {
			var isNewRenderer:Boolean = false;
			var isNullData:Boolean = (mode & USE_NULL_DATA) != 0;
			var rendererLen:uint = renderList.length;
			//если изменилось видимое количество рядов или строк то это должно приводить к изменению contentW/contentH
			if (isGeometryPhase && (mode & USE_VISIBLE_CALC_LAYOUT) != 0) {
				var oldCount:uint = getRendererVisibleCount();
			}
			if ((mode & SELECTED_MODE) != 0) {
				var oldSelected:uint = getRendererIndex(selectDataIndex);
			}

			var renderer:VRenderer = renderList[0];
			var childIndex:int = renderer.parent ? getChildIndex(renderer) : numChildren; //все рендереры будут идти в порядке от 1го
			const isFilter:Boolean = useFilterItem;
			for (var i:uint = 0; i < _maxRenderer; i++) {
				var dataIndex:uint = dpIndex + i;
				var data:Object = isFilter ? getFilterData(dataIndex) : getData(dataIndex);
				if (data || isNullData) {
					if (i == rendererLen) {
						renderer = createRenderer();
						addChildAt(renderer, childIndex + i);
						renderList.push(renderer);
						isNewRenderer = true;
						rendererLen++;
					} else {
						renderer = renderList[i];
						if (!renderer.parent) {
							addChildAt(renderer, childIndex + i);
						}
					}
					renderer.dataIndex = dataIndex;
					renderer.setData(data);
				} else {
					if (i < rendererLen) {
						renderer = renderList[i];
						if (renderer.parent) {
							removeChild(renderer);
						}
					}
				}
			}

			if ((mode & SELECTED_MODE) != 0) {
				dataIndex = getRendererIndex(selectDataIndex);
				if (oldSelected != dataIndex) {
					changeSelected(oldSelected, false, false);
					changeSelected(dataIndex, true, false);
				}
			}

			if (isGeometryPhase) {
				if ((mode & USE_VISIBLE_CALC_LAYOUT) != 0) {
					if (checkChangeVisibleCount(oldCount)) {
						syncContentSize(true);
						return;
					}
				}
				if (isNewRenderer) {
					updateRendererPos();
				}
			}
		}

		private function getRendererVisibleCount():uint {
			var count:uint = 0;
			for each (var renderer:VRenderer in renderList) {
				if (renderer.parent) {
					count++;
				}
			}
			return count;
		}

		private function checkChangeVisibleCount(oldCount:uint):Boolean {
			var newCount:uint = getRendererVisibleCount();
			var v:uint = Math.ceil(newCount / _hCount);
			return (v != Math.ceil(oldCount / _hCount) || (v == 1 && newCount != oldCount));
		}

		protected function updateRendererPos():void {
			var hCount:uint;
			var vCount:uint;
			if ((mode & USE_VISIBLE_CALC_LAYOUT) != 0) {
				hCount = getRendererVisibleCount();
				if (hCount == 0) {
					hCount = 1;
				}
				vCount = Math.ceil(hCount / _hCount);
				if (hCount > _hCount) {
					hCount = _hCount;
				}
				if (vCount > _vCount) {
					vCount = _vCount;
				}
			} else {
				hCount = _hCount;
				vCount = _vCount;
			}

			var rw:uint = renderList[0].layoutW;
			if ((mode & H_STRETCH) != 0 || rw == 0) {
				rw = (w - (hCount - 1) * _hGap) / hCount;
			}
			var sx:Number = w - ((rw + _hGap) * hCount - _hGap);
			if (sx > 0 && (mode & USE_TOP_LEFT) == 0) {
				sx = Math.round(sx / 2); //делим на 2
			} else {
				sx = 0;
			}

			var rh:uint = renderList[0].layoutH;
			if ((mode & V_STRETCH) != 0 || rh == 0) {
				rh = (h - (vCount - 1) * _vGap) / vCount;

			}
			var sy:Number = h - ((rh + _vGap) * vCount - _vGap);
			if (sy > 0 && (mode & USE_TOP_LEFT) == 0) {
				sy = Math.round(sy / 2);
			} else {
				sy = 0;
			}

			var rendererIndex:uint = 0;
			const rendererLen:uint = renderList.length;
			for (var j:uint = 0; j < vCount; j++) {
				var y:Number = Math.round(j * (rh + _vGap)) + sy;
				for (var i:uint = 0; i < hCount; i++) {
					var renderer:VRenderer = renderList[rendererIndex];

					renderer.left = renderer.x = Math.round(i * (rw + _hGap) + sx);
					renderer.y = y;
					renderer.setGeometrySize(rw, rh, false);

					rendererIndex++;
					if (rendererIndex == rendererLen) {
						return;
					}
				}
			}
		}

		override public function dispose():void {
			if (control) {
				control.dispose();
			}
			super.dispose();
		}

		override protected function customUpdate():void {
			var isHCalc:Boolean = (mode & CALC_H_COUNT) != 0;
			var isVCalc:Boolean = (mode & CALC_V_COUNT) != 0;
			if (isHCalc || isVCalc) {
				isGeometryPhase = false;
				changeRendererCount(
					(isHCalc && (layoutW <= 0 || (right != EMPTY && left != EMPTY))) ? Math.floor(w / (renderList[0].layoutW + _hGap)) : _hCount,
					(isVCalc && (layoutH <= 0 || (bottom != EMPTY && top != EMPTY))) ? Math.floor(h / (renderList[0].layoutH + _vGap)) : _vCount,
					null, 0, false
				);
				isGeometryPhase = true;
			}

			updateRendererPos();
			/*
			if (emptyComponent) {
				emptyComponent.geometryPhase();
			}
			*/
			for (var i:int = numChildren - 1; i >= 0; i--) {
				var component:VComponent = getChildAt(i) as VComponent;
				if (component && !(component is VRenderer)) {
					component.geometryPhase();
				}
			}
		}

		override public function add(component:VComponent, layout:Object = null, index:int = -1):void {
			component.useRuledLayout();
			super.add(component, layout, index);
		}

		override public function remove(component:VComponent, isDispose:Boolean = true):void {
			if (!isDispose) {
				component.useRuledLayout(false);
			}
			super.remove(component, isDispose);
		}

		private function getRendererIndex(dataIndex:uint):uint {
			var len:uint = renderList.length;
			for (var i:uint = 0; i < len; i++) {
				if (renderList[i].dataIndex == dataIndex) {
					return i;
				}
			}
			return uint.MAX_VALUE;
		}

		private function changeSelected(index:uint, flag:Boolean, isDataIndex:Boolean = true):void {
			if (isDataIndex) {
				index = getRendererIndex(index);
			}
			if (index < renderList.length) {
				renderList[index].setSelected(flag);
			}
		}

		public function setSelected(value:uint = uint.MAX_VALUE):void {
			if (selectDataIndex == value) {
				if ((mode & USE_INVERT_SELECT) != 0) {
					changeSelected(value, false);
					selectDataIndex = uint.MAX_VALUE;
				}
			} else {
				changeSelected(selectDataIndex, false);
				changeSelected(value, true);
				selectDataIndex = value;
			}
		}

		private function onSelect(event:VEvent):void {
			setSelected(event.variance);
		}

		CONFIG::debug
		override public function getToolPropList(out:Array):void {
			out.push(
				new VOComponentItem('hCount', VOComponentItem.DIGIT, _hCount),
				new VOComponentItem('vCount', VOComponentItem.DIGIT, _vCount),
				new VOComponentItem('hGap', VOComponentItem.DIGIT, _hGap),
				new VOComponentItem('vGap', VOComponentItem.DIGIT, _vGap)
			);
		}

		CONFIG::debug
		override public function updateToolProp(item:VOComponentItem):void {
			switch (item.key) {
				case 'hCount':
					changeRendererCount(item.valueInt, _vCount);
					break;

				case 'vCount':
					changeRendererCount(_hCount, item.valueInt);
					break;

				case 'hGap':
					hGap = item.valueInt;
					break;

				case 'vGap':
					vGap = item.valueInt;
					break;
			}
		}

		public function getEmptyComponent():VComponent {
			return emptyComponent;
		}

	} //end class
}