package ui.vbase {
	
	public class VGridPanel extends VBaseComponent {
		public static const ALLOW_HIDE:uint = 2;
		public static const FILTER_MODE:uint = 0x1,
			/**
			 * Растягивать по горизонтали
			 */
			H_STREACH:uint = 0x2,
			/**
			 * Растягивать по вертикали
			 */
			V_STREACH:uint = 0x4,
			H_CENTER:uint = 0x8,
			V_CENTER:uint = 0x10,
			/**
			 * Использовать текст "здесь пусто" в случае пустого списка данных
			 */
			EMPTY_TEXT:uint = 0x20,
			/**
			 * Данные могут показываться с произвольного индекса
			 * Поведение по умолчанию - выравнивание относительно количества рендеров
			 */
			DRIFT_INDEX:uint = 0x40;
		
		public var renders:Vector.<VAbstractItemRenderer> = new Vector.<VAbstractItemRenderer>();
		private var dataProvider:Array; //отказался от использования Vector.<Object>
		private var $hgap:uint;
		private var $vgap:uint;
		private var col:uint;
		
		/**
		 * Индекс первого элемента
		 */
		private var dpIndex:uint;
		private var filterIndex:uint;
		/**
		 * Количество элементов в списке данных
		 */
		private var dpLength:uint;
		private var useFilterItem:Boolean;
		private var mode:uint;
		private var classItemRenderer:Class;
		private var lbEmpty:VLabel;
		private var emptyText:String;
		
		/**
		 * Сетка панель
		 * 
		 * @param	col						Количество столбцов (x)
		 * @param	row						Количество рядов (y)
		 * @param	classItemRenderer		Класс рендерера
		 * @param	dp						Список данных
		 * @param	hgap					Горизонтальный пробел
		 * @param	vgap					Вертикальный пробел
		 * @param	mode					Режимы
		 * @param	index					Индекс первого элемента
		 */
		public function VGridPanel(col:uint, row:uint, classItemRenderer:Class, dp:Array, hgap:uint = 0, vgap:uint = 0,
		mode:uint = 0, index:uint = 0):void {
			if (col == 0) {
				col = 1;
			}
			if (row == 0) {
				row = 1;
			}
			
			for (var i:uint = 0; i < col; i++) {
				for (var j:uint = 0; j < row; j++) {
					var renderer:VAbstractItemRenderer = new classItemRenderer();
					renderer.dispatcher = this;
					renderer.visible = false;
					
					renders.push(renderer);
					addChild(renderer);
				}
			}
			
			this.col = col;
			this.$hgap = hgap;
			this.$vgap = vgap;
			this.mode = mode;
			this.classItemRenderer = classItemRenderer;
			
			if (dp != null) {
				setDataProvider(dp, index);
			}
		}
		
		/**
		 * Изменить количество визуализаторов
		 * 
		 * @param	col			Количество столбцов
		 * @param	row			Количестов рядов
		 * @param	newDp		Новый список данных (опционально)
		 * @param	index		Начальный индекс (опционально, если задано newDp)
		 */
		public function changeRendererCount(col:uint, row:uint, newDp:Array = null, index:uint = 0):void {
			if (col == 0) {
				col = 1;
			}
			if (row == 0) {
				row = 1;
			}
			
			var i:int = col * row - renders.length;
			if (i != 0) {
				this.col = col;
				var isChange:Boolean = true;
				if (i > 0) {
					while (i > 0) {
						var renderer:VAbstractItemRenderer = new classItemRenderer();
						renderer.dispatcher = this;
						renderer.visible = false;
						
						renders.push(renderer);
						addChild(renderer);
						
						i--;
					}
				} else {
					var m:uint = renders.length;
					while (i < 0) {
						m--;
						super.remove(renders[m]);
						i++;
					}
					renders.length = m;
				}
			} else if (this.col != col) {
				this.col = col;
				isChange = true;
			}
			
			if (newDp) {
				setDataProvider(newDp, index);
			} else if (isChange) {
				sync();
			}
			if (isChange) {
				syncContentSize(true);
			}
		}
		
		override protected function calcContentSize():void {
			var v:uint = renders[0].measuredWidth * col;
			if (v == 0) {
				v = 100;
			} else if (col > 1) {
				v += hgap * (col - 1);
			}
			contentW = v;
			
			var row:uint = renders.length / col;
			v = renders[0].measuredHeight * row;
			if (v == 0) {
				v = 100;
			} else {
				v += vgap * (row - 1);
			}
			contentH = v;
		}
		
		public function get vgap():uint {
			return $vgap;
		}
		
		public function set vgap(value:uint):void {
			$vgap = value;
			syncContentSize(true);
		}
		
		public function get hgap():uint {
			return $hgap;
		}
		
		public function set hgap(value:uint):void {
			$hgap = value;
			syncContentSize(true);
		}
		
		public function get numColumn():uint {
			return col;
		}
		
		public function get numRow():uint {
			return renders.length / col;
		}
		
		public function getMode():uint {
			return mode;
		}
		
		public function setMode(value:uint):void {
			mode = value;
			if (isGeometryPhase) {
				updatePhase(true);
			}
		}

		public function setDataProvider(dp:Array, index:uint = 0):void {
			dataProvider = dp;
			dpIndex = index;
			sync();
		}
		
		private function applyIndex():void {
			if (dpIndex > 0) {
				var num:uint = renders.length;
				if (dpLength <= num) {
					dpIndex = 0;
				} else {
					if (dpIndex >= dpLength) {
						dpIndex = dpLength - 1;	
					}
					if ((mode & DRIFT_INDEX) == 0) {// корректируем индекс, чтобы данные остались на своих страницах и не было дырок
						dpIndex = uint(dpIndex / num) * num;
					}
				}
			}
			if (useFilterItem) {
				num = dataProvider.length;
				if (dpIndex < dpLength) {
					var j:uint;
					for (var i:uint; i < num; i++) {
						var item:VOGridFilterItem = dataProvider[i] as VOGridFilterItem;
						if (!item.isHide && !item.isFilterHide) {
							if (j == dpIndex) {
								filterIndex = i;
								return;
							} else {
								j++;
							}
						}
					}
				}
				filterIndex = num;
			}
		}
		
		public function sync(index:int = -1):void {
			if (index >= 0) {
				dpIndex = index;
			}
			if (mode & FILTER_MODE) {
				useFilterItem = dataProvider && dataProvider.length > 0 && dataProvider[0] is VOGridFilterItem;
			}
			if (dataProvider) {
				if (useFilterItem) {
					var num:uint;
					for each (var item:VOGridFilterItem in dataProvider) {
						if (!item.isHide && !item.isFilterHide) {
							num++;
						}
					}
					dpLength = num;
				} else {
					dpLength = dataProvider.length;
				}
				applyIndex();
				updateRendererData();
				dispatchEvent(new VEvent(VEvent.GRID_INDEX, dpIndex));
			}

			if (mode & EMPTY_TEXT) {
				if (dpLength == 0) {
					if (!lbEmpty) {
						lbEmpty = new VLabel(null, VLabel.VERTICAL_MIDDLE | VLabel.CENTER);
						updateEmptyText();
						addChild(lbEmpty);
						lbEmpty.getLayout().assign( { left:10, right:10, h:'100%' } );
						if (isGeometryPhase) {
							lbEmpty.geometryPhase();
						}
					}
				} else {
					if (lbEmpty) {
						super.remove(lbEmpty);
						lbEmpty = null;
					}
				}
			}
		}
		
		public function getDataProvider():Array {
			return dataProvider;
		}
		
		public function get length():uint {
			return dpLength;
		}
		
		public function get numRenderer():uint {
			return renders.length;
		}
		
		public function get index():uint {
			return dpIndex;
		}
		
		public function set index(value:uint):void {
			if (dpIndex != value) {
				dpIndex = value;
				if (dataProvider) {
					applyIndex();
					updateRendererData();
					dispatchEvent(new VEvent(VEvent.GRID_INDEX, dpIndex));
				}
			}
		}
		
		public function clear():void {
			dataProvider = null;
			dpLength = 0;
			dpIndex = 0;
			useFilterItem = false;
			updateRendererData();
		}
		
		/**
		 * Полное обновление данных
		 */
		public function updateRendererData():void {
			var rendererIndex:uint;
			var rendererNum:uint = renders.length;
			var startIndex:uint = useFilterItem ? filterIndex : dpIndex;
			var dataNum:uint = dataProvider ? dataProvider.length : 0;
			
			//обновляем данные
			for (var dataIndex:uint = startIndex; dataIndex < dataNum && rendererIndex < rendererNum; dataIndex++) {
				if (useFilterItem) {
					var item:VOGridFilterItem = dataProvider[dataIndex] as VOGridFilterItem;
					if (item.isFilterHide || item.isHide) {
						continue;
					}
				}
				
				var renderer:VAbstractItemRenderer = renders[rendererIndex];
				renderer.dataIndex = startIndex + rendererIndex;
				renderer.setData(dataProvider[dataIndex]);
				renderer.visible = true;
				rendererIndex++;
			}
			
			//скрытые
			while (rendererIndex < rendererNum) {
				renders[rendererIndex].visible = false;
				rendererIndex++;
			}
		}
		
		override protected function syncChildLayout(component:VBaseComponent):void {
			component.updatePhase(true);
		}
		
		override protected function customUpdate():void {
			var row:uint = renders.length / col;
			
			var rw:Number = renders[0].measuredWidth;
			if ((mode & H_STREACH) != 0 || rw == 0) {
				rw = (w - (col - 1) * $hgap) / col;
			} else if (mode & H_CENTER) {
				var sx:int = w - ((rw + $hgap) * col - $hgap);
				if (sx > 0) {
					sx >>= 1; //делим на 2
				} else {
					sx = 0;
				}
			}
			
			var rh:Number = renders[0].measuredHeight;
			if ((mode & V_STREACH) != 0 || rh == 0) {
				rh = (h - (row - 1) * $vgap) / row;
			} else if (mode & V_CENTER) {
				var sy:int = h - ((rh + $vgap) * row - $vgap);
				if (sy > 0) {
					sy >>= 1;
				} else {
					sy = 0;
				}
			}
			
			var rendererIndex:uint;
			for (var j:uint; j < row; j++) {
				var y:Number = Math.round(j * (rh + $vgap)) + sy;
				for (var i:uint = 0; i < col; i++) {
					var renderer:VAbstractItemRenderer = renders[rendererIndex];
					rendererIndex++;
					
					renderer.x = Math.round(i * (rw + $hgap)) + sx;
					renderer.y = y;
					renderer.setGeometrySize(rw, rh, false);
				}
			}
			
			if (lbEmpty) {
				lbEmpty.geometryPhase();
			}
		}
		
		override public function add(component:VBaseComponent, layout:Object = null, index:int = -1):void {
			throw new Error('VGridPanel no use add method');
		}
		
		override public function remove(component:VBaseComponent, isDispose:Boolean = true):void {
			throw new Error('VGridPanel no use remove method');
		}
		
		/**
		 * Текст выводимый в случае пустого списка данных, актуально только для режима EMPTY_TEXT
		 * 
		 * @param	value		Текст с форматированием (центрировать не нужно)
		 */
		public function setEmptyText(value:String):void {
			emptyText = value;
			if (lbEmpty) {
				updateEmptyText();
			}
		}
		
		private function updateEmptyText():void {
			lbEmpty.text = '<div fontSize="22">' + (emptyText ? emptyText :'empty_dp') + '</div>';
		}
		
	} //end class
}