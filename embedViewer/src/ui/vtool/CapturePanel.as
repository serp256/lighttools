package ui.vtool {
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.MouseEvent;
	import flash.geom.Point;

	import ui.vbase.GridControl;
	import ui.vbase.VButton;
	import ui.vbase.VComponent;
	import ui.vbase.VEvent;
	import ui.vbase.VGrid;
	import ui.vbase.VScrollBar;

	public class CapturePanel extends VComponent {
		private const
			targetBt:VButton = VToolPanel.createTextButton('Цель', onTarget),
			depthBt:VButton = VToolPanel.createTextButton('Дети', onDepth, 'Orange'),
			grid:VGrid = new VGrid(1, 7, CaptureRenderer, null, 0, 4, VGrid.H_STRETCH | VGrid.FLOAT_INDEX)
			;
		private var
			depthPanel:DepthPanel,
			isListener:Boolean
			;
		
		public function CapturePanel() {
			add(grid, { left:0, right:21, bottom:3 });
			grid.addListener(VEvent.SELECT, onSelectTarget);
			var scroll:VScrollBar = VToolPanel.createScrollBar();
			add(scroll, { right:0, bottom:3, h:grid.measuredHeight });
			(new GridControl(grid)).assignScrollBar(scroll);
			
			grid.addListener(VEvent.VARIANCE, onVariance);
			
			add(targetBt, { w:60 });
			add(depthBt, { w:60, left:65 });
			depthBt.disabled = true;
		}
		
		override public function dispose():void {
			onMouse(null);
			super.dispose();
		}
		
		/**
		 * Обработчик выбора нового таргета
		 * 
		 * @param	event
		 */
		private function onSelectTarget(event:VEvent):void {
			if (depthPanel) {
				onBackDepthPanel(null);
			}
			ComponentPanel.target = event.data;
			onMouseMove(event.data);
			checkDepth();
		}
		
		public function onTarget(event:MouseEvent = null):void {
			if (isListener || !stage) {
				return;
			}
			targetBt.disabled = true;
			depthBt.disabled = true;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, true, 10000);
			stage.addEventListener(MouseEvent.CLICK, onMouse, true, 10000);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouse, true, 10000);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouse, true, 10000);
			isListener = true;
		}

		private function isSolidMode(component:VComponent):Boolean {
			return component && (component.getMode() & VComponent.V_TOOL_SOLID) != 0;
		}
		
		/**
		 * Обработчик MouseEvent.MOUSE_MOVE
		 * 
		 * @param	data
		 */
		private function onMouseMove(data:Object):void {
			VToolPanel.clearCounter();

			var target:DisplayObject = ((data is MouseEvent) ? (data as MouseEvent).target : data) as DisplayObject;
			//пытаемся найти родительский VBaseComponent
			while (target && !(target is VComponent)) {
				target = target.parent;
			}

			if (!target) {
				grid.setDataProvider(null);
				return;
			} else if (data is MouseEvent && !isSolidMode(target as VComponent)) {
				var container:VComponent = target as VComponent;
				var event:MouseEvent = data as MouseEvent;
				var emptyPoint:Point = new Point();

				do {
					var component:VComponent = null;
					for (var i:int = container.numChildren - 1; i >= 0; i--) {
						var obj:DisplayObject = container.getChildAt(i);
						if (obj is VComponent) {
							component = obj as VComponent;
							var p:Point = component.localToGlobal(emptyPoint);
							if (event.stageX >= p.x && event.stageX < p.x + component.w && event.stageY >= p.y && event.stageY < p.y + component.h) {
								target = component;
								if (isSolidMode(component)) {
									component = null;
									break;
								} else {
									container = component;
								}
								break;
							} else {
								component = null;
							}
						}
					}
				} while (component);
			}

			var pathList:Array = [];
			while (target && !(target is Stage)) {
				if (target == VToolPanel.instance) {
					pathList = null;
					break;
				}
				
				pathList.push(target);
				target = target.parent;
				//если isSolidMode тогда дочерние скрыты
				/*
				if (target is VComponent && isSolidMode(target as VComponent)) {
					pathList.length = 0;
				}
				*/
			}

			if (pathList) {
				while (pathList.length > 0 && ((pathList[0] as VComponent).getMode() & VComponent.V_TOOL_HIDDEN) != 0) {
					pathList.shift();
				}
			}

			ComponentPanel.target = (pathList && pathList.length > 0) ? pathList[0] as VComponent : null;
			grid.setDataProvider(pathList);
			VToolPanel.drawCounter();
		}
		
		/**
		 * Обработчик MouseEvent.CLICK
		 * Для событий MouseEvent.MOUSE_UP, MouseEvent.MOUSE_DOWN просто идет вызов stopImmediatePropagation
		 * 
		 * @param	event
		 */
		private function onMouse(event:MouseEvent):void {
			if (event) {
				event.stopImmediatePropagation();
				if (event.type != MouseEvent.CLICK) {
					return;
				}
			}
			
			if (isListener) {
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, true);
				stage.removeEventListener(MouseEvent.MOUSE_UP, onMouse, true);
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouse, true);
				stage.removeEventListener(MouseEvent.CLICK, onMouse, true);
				isListener = false;
			}
			
			if (event) {
				targetBt.disabled = false;
				checkDepth();
				if (ComponentPanel.target) { //переключаем на вкладку компонента
					VToolPanel.instance.onChangeTab(VToolPanel.instance.componentBt);
				}
			}
		}
		
		/**
		 * Проверка наличие дочерних VBaseComponent
		 */
		private function checkDepth():void {
			var pathList:Array = grid.getDataProvider();
			var sp:Sprite = (pathList && pathList.length > 0) ? pathList[0] as Sprite : null;
			var flag:Boolean = true;
			if (sp) {
				for (var i:int = sp.numChildren - 1; i >= 0; i--) {
					if (sp.getChildAt(i) is VComponent) {
						flag = false;
					}
				}
			}
			depthBt.disabled = flag;
		}
		
		/**
		 * Открывает выбор дочернего элемента текущего VBaseComponent
		 * 
		 * @param	event
		 */
		private function onDepth(event:MouseEvent):void {
			var pathList:Array = grid.getDataProvider();
			var sp:Sprite = pathList[0] as Sprite;
			var dpList:Array = [];
			for (var i:int = sp.numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = sp.getChildAt(i);
				if (obj is VComponent) {
					dpList.push(obj);
				}
			}
			
			depthPanel = new DepthPanel(dpList);
			depthPanel.backBt.addListener(MouseEvent.CLICK, onBackDepthPanel);
			depthPanel.addListener(VEvent.SELECT, onSelectTarget);
			addStretch(depthPanel);
			depthPanel.addListener(VEvent.VARIANCE, onVariance);
		}
		
		/**
		 * Обработчик клика по кнопке "Назад" панели depth
		 * 
		 * @param	event		Объект события MouseEvent.CLICK
		 */
		private function onBackDepthPanel(event:MouseEvent):void {
			remove(depthPanel);
			depthPanel = null;
		}

		private function onVariance(event:VEvent):void {
			VToolPanel.drawCounter((event.variance == 1) ? event.data : null);
		}
		
	} //end class
}