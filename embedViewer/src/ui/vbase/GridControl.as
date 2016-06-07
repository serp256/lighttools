package ui.vbase {
	import flash.events.MouseEvent;

	public class GridControl {
		public static const
			NAV_BT_VISIBLE:uint = 1,
			NAV_BT_DISABLED:uint = 2,
			NAV_SMART:uint = 3,
			PAGER_VISIBLE:uint = 4,
			PAGER_CALC_COUNT:uint = 8,
			SMART:uint = NAV_BT_VISIBLE | NAV_BT_DISABLED | PAGER_VISIBLE,
			NAV_VERTICAL:uint = 4096
			;
		public var
			grid:VGrid,
			scrollBar:VScrollBar,
			pager:VPager,
			prevBt:VButton,
			nextBt:VButton,
			navBtFactory:Function, //(isFlip, isVertical)
			pagerFactory:Function
			;
		protected var mode:uint;
		private var
			addNavBtFunc:Function,
			addPagerFunc:Function
			;
		
		public function GridControl(grid:VGrid, mode:uint = 0) {
			this.grid = grid;
			grid.control = this;
			this.mode = mode;
			grid.addListener(VEvent.CHANGE, onChangeIndex);
		}

		public function dispose():void {
			assignNavButtons();
			assignPager(null);
			assignScrollBar(null);
			grid.removeListener(VEvent.CHANGE, onChangeIndex);
			grid.control = null;
		}

		protected function onChangeIndex(event:VEvent):void {
			if ((mode & GridControl.NAV_BT_VISIBLE) != 0) {
				if (!nextBt && grid.length > grid.maxRenderer) {
					createNavBt();
				}
			}
			if ((mode & GridControl.PAGER_VISIBLE) != 0) {
				if (!pager && grid.length > grid.maxRenderer) {
					createPager();
				}
			}
			if (pager) {
				syncPager();
			}
			if (prevBt || nextBt) {
				syncNavButton();
			}
			if (scrollBar) {
				syncScrollBar();
			}
		}

		//---Pager---

		public function assignPager(pager:VPager):void {
			if (this.pager) {
				this.pager.removeListener(VEvent.SELECT, onChangePage);
			}
			this.pager = pager;
			if (pager) {
				pager.addListener(VEvent.SELECT, onChangePage);
				syncPager();
			}
		}

		//сменилась страница
		private function onChangePage(event:VEvent):void {
			grid.index = uint(event.data) * grid.maxRenderer;
		}

		protected function syncPager():void {
			var num:uint = grid.maxRenderer;
			var showCount:uint = Math.ceil(grid.length / num);
			pager.setParam(Math.ceil(grid.index / num), showCount, (mode & PAGER_CALC_COUNT) != 0 ? showCount : 0);
			if ((mode & PAGER_VISIBLE) != 0) {
				pager.visible = grid.length > 0;
			}
		}

		//---Navigate buttons---
		
		public function assignNavButtons(prevBt:VButton = null, nextBt:VButton = null):void {
			if (this.prevBt) {
				this.prevBt.removeListener(MouseEvent.CLICK, onNavButton);
				this.prevBt.visible = true;
			}
			this.prevBt = prevBt;
			if (prevBt) {
				prevBt.addClickListener(onNavButton);
			}
			
			if (this.nextBt) {
				this.nextBt.removeListener(MouseEvent.CLICK, onNavButton);
				this.nextBt.visible = true;
			}
			this.nextBt = nextBt;
			if (nextBt) {
				nextBt.addClickListener(onNavButton);
			}
			if (prevBt || nextBt) {
				syncNavButton();
			}
		}
		
		private function onNavButton(event:MouseEvent):void {
			var max:uint = grid.length;
			var index:uint = grid.index;
			var bValue:uint = grid.maxRenderer;
			
			if (event.currentTarget == prevBt) {
				if (bValue > index) {
					if (index == 0) {
						index = uint(max / bValue) * bValue;
					} else {
						index = 0;
					}
				} else {
					index -= bValue;
				}
			} else if (index + bValue >= max) {
				index = 0;
			} else {
				index += bValue;
			}
			grid.index = index;
		}

		protected function syncNavButton():void {
			var useVisible:Boolean = (mode & NAV_BT_VISIBLE) != 0;
			var useDisabled:Boolean = (mode & NAV_BT_DISABLED) != 0;
			if (prevBt) {
				if (useVisible) {
					prevBt.visible = grid.length > grid.maxRenderer;
				}
				if (useDisabled) {
					prevBt.disabled = grid.index == 0;
				}
			}
			if (nextBt) {
				if (useVisible) {
					nextBt.visible = grid.length > grid.maxRenderer;
				}
				if (useDisabled) {
					nextBt.disabled = grid.index >= grid.length - grid.maxRenderer;
				}
			}
		}

		//---ScrollBar---
		
		public function assignScrollBar(scrollBar:VScrollBar):void {
			if (this.scrollBar) {
				this.scrollBar.removeListener(VEvent.SCROLL, onScroll);
			}
			this.scrollBar = scrollBar;
			if (scrollBar) {
				scrollBar.addListener(VEvent.SCROLL, onScroll);
				syncScrollBar();
			}
		}
		
		private function onScroll(event:VEvent):void {
			grid.index = uint(event.data);
		}

		protected function syncScrollBar():void {
			if (grid.length != scrollBar.getMax() || grid.maxRenderer != scrollBar.getPageSize()) {
				scrollBar.setEnv(grid.maxRenderer, grid.length, grid.index);
			} else {
				scrollBar.value = grid.index;
			}
		}

		private function createNavBt():void {
			if (navBtFactory == null) {
				return;
			}
			var isVertical:Boolean = (mode & NAV_VERTICAL) != 0;
			var prevBt:VButton = navBtFactory(false, isVertical);
			var nextBt:VButton = navBtFactory(true, isVertical);
			if (addNavBtFunc != null) {
				addNavBtFunc(grid, prevBt, nextBt);
			}
			assignNavButtons(prevBt, nextBt);
		}

		private function createPager():void {
			if (pagerFactory == null) {
				return;
			}
			var pager:VPager = pagerFactory();
			if (addPagerFunc != null) {
				addPagerFunc(grid, pager);
			}
			assignPager(pager);
		}

		public static function assign(grid:VGrid, mode:uint, navBtFactory:Function, addNavBtFunc:Function, pagerFactory:Function = null, addPagerFunc:Function = null):void {
			var connector:GridControl = new GridControl(grid, mode);
			connector.navBtFactory = navBtFactory;
			var flag:Boolean = grid.length > grid.maxRenderer;
			if (addNavBtFunc != null) {
				connector.addNavBtFunc = addNavBtFunc;
				if (flag || (mode & GridControl.NAV_BT_VISIBLE) == 0) {
					connector.createNavBt();
				}
			}
			connector.pagerFactory = pagerFactory;
			if (addPagerFunc != null) {
				connector.addPagerFunc = addPagerFunc;
				if (flag || (mode & GridControl.PAGER_VISIBLE) == 0) {
					connector.createPager();
				}
			}
		}
		
	} //end class
}