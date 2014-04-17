package ui {
	import flash.events.MouseEvent;
	import ui.common.PagePanel;
	import ui.vbase.*;
	
	/**
	 * Страницы + стрелки влево-вправо + скролл
	 */
	public class GridConnector {
		private var gridPanel:VGridPanel;
		private var scrollBar:VScrollBar;
		private var pagePanel:PagePanel;
		private var prevButton:VButton;
		private var nextButton:VButton;
		private var isPagePanelVisible:Boolean;
		private var isStronglyRange:Boolean;
		
		public static function createWithScroll(gridPanel:VGridPanel, scrollBar:VScrollBar):GridConnector {
			var connector:GridConnector = new GridConnector(gridPanel);
			connector.assignScrollBar(scrollBar);
			return connector;
		}
		
		public static function createWithPage(gridPanel:VGridPanel, prevButton:VButton = null, nextButon:VButton = null):GridConnector {
			var connector:GridConnector = new GridConnector(gridPanel);
			connector.assignPagePanel();
			if (prevButton || nextButon) {
				connector.assignButtons(prevButton, nextButon);
			}
			return connector;
		}
		
		public function GridConnector(gridPanel:VGridPanel):void {
			this.gridPanel = gridPanel;
		}

		public function changeStronglyRange(value:Boolean):void {
			isStronglyRange = value;
			syncLockButton();
		}

		private function syncLockButton():void {
			var index:uint = gridPanel.index;
			if (prevButton && prevButton.visible) {
				prevButton.disabled = isStronglyRange && index == 0;
			}
			if (nextButton && nextButton.visible) {
				nextButton.disabled = isStronglyRange && index >= gridPanel.length - gridPanel.numRenderer;
			}
		}
		
		public function getGridPanel():VGridPanel {
			return gridPanel;
		}
		
		public function changeGridPanel(newGridPanel:VGridPanel):void {
			gridPanel = newGridPanel;
			full_syncUI();
		}
		
		public function get index():uint {
			return gridPanel.index;
		}
		
		public function get dataProvider():Array {
			return gridPanel.getDataProvider();
		}
		
		private function syncUI(isPagePanel:Boolean = true, isScrollBar:Boolean = true):void {
			var index:uint = gridPanel.index;
			if (isPagePanel && pagePanel) {
				pagePanel.index = index / gridPanel.numRenderer;
			}
			if (isScrollBar && scrollBar) {
				scrollBar.scrollPosition = index;
			}
			if (isStronglyRange) {
				syncLockButton();
			}
			gridPanel.dispatchEvent(new VEvent(VEvent.CHANGE));
		}
		
		private function full_syncUI():void {
			var numRenderer:uint = gridPanel.numRenderer;
			var index:uint = gridPanel.index;
			var len:uint = gridPanel.length;
			var pageNum:uint = Math.ceil(len / numRenderer);
			if (pagePanel) {
				pagePanel.setParam(index / numRenderer, pageNum);
				if (isPagePanelVisible) {
					pagePanel.visible = len > 1;
				}
			}
			var isVisible:Boolean = pageNum > 1;
			if (prevButton) {
				prevButton.visible = isVisible;
			}
			if (nextButton) {
				nextButton.visible = isVisible;
			}
			syncLockButton();
			if (scrollBar) {
				scrollBar.setProperties(numRenderer, len, index, numRenderer);
			}
		}
		
		/**
		 * Назначить панель страниц
		 * 
		 * @param	num				Количество видимых кнопок страниц
		 * @param	useVisible		Скрывать панель если список данных пуст
		 */
		public function assignPagePanel(num:uint = 9, useVisible:Boolean = false):void {
			if (pagePanel) {
				pagePanel.removeListener(VEvent.SELECT, onChangePageHandler);
			}
			pagePanel = new PagePanel(num, gridPanel.index / gridPanel.numRenderer, Math.ceil(gridPanel.length / gridPanel.numRenderer));
			pagePanel.addListener(VEvent.SELECT, onChangePageHandler);
			
			isPagePanelVisible = useVisible;
			if (useVisible) {
				pagePanel.visible = gridPanel.length > 0;
			}
		}
		
		public function getPagePanel():PagePanel {
			return pagePanel;
		}
		
		private function onChangePageHandler(event:VEvent):void {
			var pageIndex:uint = event.data as uint;
			gridPanel.index = pageIndex * gridPanel.numRenderer;
			syncUI(false);
		}
		
		public function assignButtons(prevButton:VButton = null, nextButton:VButton = null):void {
			var isVisible:Boolean = Math.ceil(gridPanel.length / gridPanel.numRenderer) > 1;
			if (this.prevButton) {
				this.prevButton.removeListener(MouseEvent.CLICK, onClickHandler);
			}
			this.prevButton = prevButton;
			if (prevButton) {
				prevButton.addListener(MouseEvent.CLICK, onClickHandler);
				prevButton.visible = isVisible;
			}
			
			if (this.nextButton) {
				this.nextButton.removeListener(MouseEvent.CLICK, onClickHandler);
			}
			this.nextButton = nextButton;
			if (nextButton) {
				nextButton.addListener(MouseEvent.CLICK, onClickHandler);
				nextButton.visible = isVisible;
			}
			syncLockButton();
		}
		
		public function getPrevButton():VButton {
			return prevButton;
		}
		
		public function getNextButton():VButton {
			return nextButton;
		}
		
		private function onClickHandler(event:MouseEvent):void {
			var max:uint = gridPanel.length;
			var index:uint = gridPanel.index;
			var bValue:uint = gridPanel.numRenderer;
			
			if (event.currentTarget == prevButton) {
				if (index - bValue < 0) {
					index = gridPanel.numRenderer;
					index = uint(max / index) * index;
				} else {
					index -= bValue;
				}
			} else if (index + bValue >= max) {
				index = 0;
			} else {
				index += bValue;
			}
			gridPanel.index = index;
			syncUI();
		}
		
		public function assignScrollBar(scrollBar:VScrollBar):void {
			if (this.scrollBar) {
				this.scrollBar.removeListener(VEvent.SCROLL, onScrollHandler);
			}
			this.scrollBar = scrollBar;
			if (scrollBar) {
				scrollBar.addListener(VEvent.SCROLL, onScrollHandler);
				var num:uint = gridPanel.numRenderer;
				scrollBar.setProperties(num, gridPanel.length, gridPanel.index, num);
			}
		}
		
		public function getScrollBar():VScrollBar {
			return scrollBar;
		}
		
		private function onScrollHandler(event:VEvent):void {
			gridPanel.index = uint(event.data);
			syncUI(true, false);
		}
		
		
		public function syncDp(index:int = -1):void {
			gridPanel.sync(index);
			full_syncUI();
		}
		
		/**
		 * Изменить список данных
		 * 
		 * @param	newDp		Новый список данных
		 * @param	index		Стартовый индекс (< 0, будет сохранен текущий)
		 */
		public function changeDp(newDp:Array, index:int = 0):void {
			if (index < 0) {
				index = gridPanel.index;
			}
			gridPanel.setDataProvider(newDp, index);
			full_syncUI();
		}

		public function changeRendererCount(col:uint, row:uint, newDp:Array = null, index:uint = 0):void {
			if (gridPanel.numColumn != col || gridPanel.numRow != row) {
				gridPanel.changeRendererCount(col, row, newDp, index);
				full_syncUI();
			} else if (newDp) {
				changeDp(newDp, index);
			}
		}
		
	} //end class
}