package ui.vtool {
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import ui.GridConnector;
	import ui.vbase.*;
	
	public class CapturePanel extends VBaseComponent {
		private var pathLabel:VLabel = new VLabel();
		private var btTarget:VButton = VToolPanel.createTextButton('VToolGreenButtonBg', 'Цель', onTargetHandler);
		private var btDepth:VButton = VToolPanel.createTextButton('VToolOrangeButtonBg', 'Дети', onDepthHandler);
		private var depthPanel:DepthPanel;
		private var isListener:Boolean;
		private var gridConnector:GridConnector;
		
		public function CapturePanel():void {
			setPathInfo('нажмите кнопку "Цель", чтобы захватить VBaseComponent, завершение захвата происходит по MouseEvent.CLICK');
			add(pathLabel, { w:'100%', h:50 } );
			
			var gridPanel:VGridPanel = new VGridPanel(1, 5, CaptureItemRenderer, null, 0, 4, VGridPanel.H_STREACH | VGridPanel.DRIFT_INDEX);
			add(gridPanel, { left:0, right:21, bottom:32 } );
			gridPanel.addListener(VEvent.SELECT, onSelectTargetHandler);
			var scroll:VScrollBar = VToolPanel.createScrollBar();
			add(scroll, { right:0, bottom:32, h:gridPanel.measuredHeight } );
			gridConnector = GridConnector.createWithScroll(gridPanel, scroll);
			
			for each (var render:CaptureItemRenderer in gridPanel.renders) {
				render.addListener(MouseEvent.ROLL_OVER, onRendererRollHandler);
				render.addListener(MouseEvent.ROLL_OUT, onRendererRollHandler);
			}
			
			add(btTarget, { w:60, bottom:0 } );
			add(btDepth, { w:60, bottom:0, left:65 } );
			btDepth.disabled = true;
		}
		
		private function setPathInfo(value:String):void {
			pathLabel.text = '<div fontSize="12" color="0x893A25">' + value + '</div>';
		}
		
		override public function dispose():void {
			onMouseHandler(null);
			super.dispose();
		}
		
		/**
		 * Обработчик выбора нового таргета
		 * 
		 * @param	event
		 */
		private function onSelectTargetHandler(event:VEvent):void {
			if (depthPanel) {
				onBackDepthPanelHandler(null);
			}
			ComponentPanel.target = event.data;
			onMouseMoveHandler(event.data);
			checkDepth();
		}
		
		private function onTargetHandler(event:MouseEvent):void {
			btTarget.disabled = true;
			btDepth.disabled = true;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMoveHandler, true, 10000);
			stage.addEventListener(MouseEvent.CLICK, onMouseHandler, true, 10000);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseHandler, true, 10000);
			stage.addEventListener(MouseEvent.MOUSE_UP, onMouseHandler, true, 10000);
			isListener = true;
		}
		
		/**
		 * Обработчик MouseEvent.MOUSE_MOVE
		 * 
		 * @param	data
		 */
		private function onMouseMoveHandler(data:Object):void {
			VToolPanel.clearCounter();
			
			var target:DisplayObject = ((data is MouseEvent) ? (data as MouseEvent).target : data) as DisplayObject;
			//пытаемся найти родительский VBaseComponent
			while (target && !(target is VBaseComponent)) {
				target = target.parent;
			}
			
			if (!target) {
				setPathInfo('не найден VBaseComponent');
				gridConnector.changeDp(null);
				return;
			} else 	if (data is MouseEvent) {
				var event:MouseEvent = data as MouseEvent;
				var container:VBaseComponent = target as VBaseComponent;
				var emptyPoint:Point = new Point();
				
				do {
					var component:VBaseComponent = null;
					for (var i:int = container.numChildren - 1; i >= 0; i--) {
						var obj:DisplayObject = container.getChildAt(i);
						if (obj is VBaseComponent) {
							component = obj as VBaseComponent;
							var p:Point = component.localToGlobal(emptyPoint);
							if (event.stageX >= p.x && event.stageX < p.x + component.w && event.stageY >= p.y && event.stageY < p.y + component.h) {
								container = component;
								target = component;
								break;
							} else {
								component = null;
							}
						}
					}
				} while (component);
			}
			
			var pathList:Array = [];
			var classList:Array = [];
			while (target && !(target is Stage)) {
				if (target == VToolPanel.instance) {
					pathList = null;
					break;
				}
				
				pathList.push(target);
				classList.unshift(VToolPanel.getClassName(target));
				
				target = target.parent;
			}
			
			setPathInfo((pathList != null) ? '<p color="0x317AC9">' + classList.join(' > ') + '</p>' : 'находимся в зоне VToolPanel');
			ComponentPanel.target = (pathList && pathList.length > 0) ? pathList[0] as VBaseComponent : null;
			gridConnector.changeDp(pathList);
			
			VToolPanel.drawCounter();
		}
		
		/**
		 * Обработчик MouseEvent.CLICK
		 * Для событий MouseEvent.MOUSE_UP, MouseEvent.MOUSE_DOWN просто идет вызов stopImmediatePropagation
		 * 
		 * @param	event
		 */
		private function onMouseHandler(event:MouseEvent):void {
			if (event) {
				event.stopImmediatePropagation();
				if (event.type != MouseEvent.CLICK) {
					return;
				}
			}
			
			if (isListener) {
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMoveHandler, true);
				stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseHandler, true);
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseHandler, true);
				stage.removeEventListener(MouseEvent.CLICK, onMouseHandler, true);
				isListener = false;
			}
			
			if (event) {
				btTarget.disabled = false;
				checkDepth();
			}
		}
		
		/**
		 * Проверка наличие дочерних VBaseComponent
		 */
		private function checkDepth():void {
			var pathList:Array = gridConnector.dataProvider;
			var sp:Sprite = (pathList && pathList.length > 0) ? pathList[0] as Sprite : null;
			var flag:Boolean = true;
			if (sp) {
				for (var i:int = sp.numChildren - 1; i >= 0; i--) {
					if (sp.getChildAt(i) is VBaseComponent) {
						flag = false;
					}
				}
			}
			btDepth.disabled = flag;
		}
		
		/**
		 * Открывает выбор дочернего элемента текущего VBaseComponent
		 * 
		 * @param	event
		 */
		private function onDepthHandler(event:MouseEvent):void {
			var pathList:Array = gridConnector.dataProvider;
			var sp:Sprite = pathList[0] as Sprite;
			var dpList:Array = [];
			for (var i:int = sp.numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = sp.getChildAt(i);
				if (obj is VBaseComponent) {
					dpList.push(obj);
				}
			}
			
			depthPanel = new DepthPanel(dpList);
			depthPanel.btBack.addListener(MouseEvent.CLICK, onBackDepthPanelHandler);
			depthPanel.addListener(VEvent.SELECT, onSelectTargetHandler);
			add(depthPanel, { w:'100%', h:'100%' } );
			
			for each (var render:CaptureItemRenderer in depthPanel.gridPanel.renders) {
				render.addListener(MouseEvent.ROLL_OVER, onRendererRollHandler);
				render.addListener(MouseEvent.ROLL_OUT, onRendererRollHandler);
			}
		}
		
		/**
		 * Обработчик клика по кнопке "Назад" панели depth
		 * 
		 * @param	event		Объект события MouseEvent.CLICK
		 */
		private function onBackDepthPanelHandler(event:MouseEvent):void {
			remove(depthPanel);
			depthPanel = null;
		}
		
		/**
		 * Обработчик roll-событий рендерера цели
		 * 
		 * @param	event
		 */
		private function onRendererRollHandler(event:MouseEvent):void {
			VToolPanel.drawCounter((event.type == MouseEvent.ROLL_OVER) ? (event.currentTarget as CaptureItemRenderer).target : null);
		}
		
	} //end class
}