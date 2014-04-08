package ui {
	import flash.display.*;
	import ui.board.BoardPanel;
	import ui.board.UserPanel;
	import ui.bottom.BottomPanel;
	import ui.common.HintPanel;
	import ui.game.LoadPanel;
	import ui.top.TopPanel;
	import ui.vbase.*;

	public class MainPanel extends VBaseComponent {
		public var boardPanel:BoardPanel = new BoardPanel();
		public var bottomPanel:BottomPanel = new BottomPanel();
		public var topPanel:TopPanel = new TopPanel();
		public var infoPanel:Sprite = new Sprite();
		public var hintPanel:HintPanel = new HintPanel();
		private var dialogPanel:VBaseComponent = new VBaseComponent();
		public var userPanel:UserPanel = new UserPanel();
		private var dialogBg:VFill;
		public var loadPanel:VBaseComponent;
		public var cursor:VBaseComponent;
		public var plantPanel:VBaseComponent;
	//	public var allowRemoval:Boolean;
		public var fake_banners:Array;

		/*
		private var menuBox:VBox;
		private var menuHandler:Function;
		private var menuData:Object;
		*/
		
		public function init():void {			
			add(boardPanel, { w:'100%', h:'100%'} );
			setUserPanelView(true);
			add(topPanel, { hCenter:-1 } );
			add(bottomPanel, { hCenter:0, bottom:3 } );
			infoPanel.mouseEnabled = infoPanel.mouseChildren = false;
			addChild(infoPanel);
			dialogPanel.mouseEnabled = false;
			add(dialogPanel, { w:'100%', h:'100%' } );
			addChild(hintPanel);			
		}
		
		/**
		 * Применить курсор
		 * 
		 * @param	value		Для скина должна быть расчитана геометрия
		 */
		public function applyCursor(value:VBaseComponent):void {
			if (cursor) {
				if (cursor.parent) {
					cursor.stopDrag();
					infoPanel.removeChild(cursor);
				}
				cursor.dispose();
				cursor = null;
			}
			if (value) {
				value.cacheAsBitmap = true;
				cursor = value;
				updateCursor();
			}
		}
		
		private function updateCursor():void { 
			if (cursor) {
				var isShowCursor:Boolean = (cursor.parent != null);
				if (isShowCursor != (dialogPanel.numChildren == 0)) {
					if (isShowCursor) {
						infoPanel.removeChild(cursor);
						cursor.stopDrag();
					} else {
						//cursor.x = mouseX + 16;
						//cursor.y = mouseY + 16;
						cursor.x = mouseX + 10;
						cursor.y = mouseY + 10;
						infoPanel.addChild(cursor);trace('updateCursor '+(cursor ? cursor.name : null));
						cursor.startDrag();
					}
				}
			}
		}

		public function applyNumCursor(value:uint, skin:VSkin = null):void { trace('applyNumCursor '+(cursor ? cursor.name : null));
			var lb:VLabel = new VLabel(null, VLabel.VERTICAL_BOTTOM);
			Style.applyBigDigitGlow(lb);
			
			if (skin) {
			    skin.setMode(VSkin.BOX);
				skin.add(lb, { w:100, h:'100%', right:-101 } );
				applyCursor(skin);
				lb.geometryPhase();
			} else {
				lb.setGeometrySize(100, 30, true);
				applyCursor(lb);
			}
			updateNumCursor(value);
		}

		public function updateNumCursor(value:uint):void { trace('updateNumCursor '+(cursor ? cursor.name : null));
			if (cursor) {
				var isLabel:Boolean = cursor is VLabel;
				var lb:VLabel = (isLabel ? cursor : cursor.getChildAt(cursor.numChildren - 1)) as VLabel;
				if (lb) {
					lb.text = '<p' + Style.def_digit + (isLabel ? '> ' : '>') + value.toString() + '</p>';
				}
			}
		}
		
		/**
		 * Показать диалог
		 * 
		 * @param	dialog		Диалог
		 * @param	isBelow		Поставить диалог как самый нижний
		 */
		public function showDialog(dialog:VBaseComponent, isBelow:Boolean = false):void {
			if (dialogPanel.numChildren > 0) {
				if (isBelow) {
					dialog.visible = false;
				} else {
					dialogPanel.getChildAt(dialogPanel.numChildren - 1).visible = false;
				}
			} else {
				//dialogBg = new VFill(0xFFFFFF, .5);
				dialogBg = new VFill(Style.bgRGB, .5);
				dialogBg.mouseEnabled = true;
				dialogPanel.add(dialogBg, { w:'100%', h:'100%' }, 0);
			}
			dialogPanel.add(dialog, { hCenter:0, vCenter:0 }, isBelow ? 1 : dialogPanel.numChildren);

			updateCursor();
		}
		
		public function closeDialog(dialog:VBaseComponent):void {
			for (var i:int = dialogPanel.numChildren - 1; i > 0; i--) {
				if (dialogPanel.getChildAt(i) == dialog) {
					dialogPanel.remove(dialog);
					if (dialogPanel.numChildren == 1) {
						dialogPanel.remove(dialogBg);
						dialogBg = null;
					} else {
						dialogPanel.getChildAt(dialogPanel.numChildren - 1).visible = true;
					}
					break;
				}
			}
			
			updateCursor();
		}

		public function getDialogPanel():VBaseComponent {
			return dialogPanel;
		}
		
		public function setLoadPanel(value:Boolean):void {
			if ((loadPanel != null) != value) {
				if (value) {
					loadPanel = new LoadPanel();
					add(loadPanel, { w:'100%', h:'100%' } );
				} else {
					remove(loadPanel);
					loadPanel = null;
				}
			}
		}
		
		public function getViewLayout():Object {
			//return { w:(Main.socialnet == Main.ODNOKLASSNIKI) ? 740 : 760, hCenter:0, top:96, bottom:160 };
			return { left:10, right:8, top:96, bottom:160 };
		}
		
		/**
		 * Задает видимость юзерской userPanel
		 * 
		 * @param	value
		 */
		public function setUserPanelView(value:Boolean):void {
			if ((userPanel.parent != null) != value) {
				if (value) {
					add(userPanel, { left:10, right:8, top:96, bottom:160 }, getChildIndex(boardPanel) + 1);
				} else {
					remove(userPanel, false);
				}
			}
		}

		/*
		public function showMenu(menuList:Vector.<VOMenu>, menuData:Object, menuHandler:Function, woStageTop:Number):void {
			hideMenu();
			
			this.menuHandler = menuHandler;
			this.menuData = menuData;
			
			var mw:uint;
			var labelList:Vector.<VLabel> = new Vector.<VLabel>();
			for each (var item:VOMenu in menuList) {
				var label:VLabel = new VLabel(item.title, VLabel.VERTICAL_MIDDLE);
				var lb_w:uint = label.contentWidth;
				if (lb_w > mw) {
					mw = lb_w;
				}
				labelList.push(label);
			}
			mw += 14;
			
			var list:Vector.<VBaseComponent> = new Vector.<VBaseComponent>();
			var num:uint = labelList.length;
			for (var i:int = 0; i < num; i++) {
				var skin:VSkin = AssetManager.getEmbedSkin('WOMenuItemBg', VSkin.STRETCH);
				var bt:VButton = UIFactory.createButton(
					skin, { w:mw, h:skin.contentHeight }, labelList[i], { left:6, right:8, h:'100%' } 
				);
				
				bt.variance = menuList[i].variance;
				bt.addClickListener(onClickMenuHandler);
				list.push(bt);
			}
			
			menuBox = new VBox(list, true, 0);
			var mx:Number = mouseX + 8;
			var my:Number = mouseY + 10;
			
			if (mx + menuBox.contentWidth > w - 6) {
				mx = w - 6 - menuBox.contentWidth;
			}
			var n:uint = (woStageTop >= h - 120) ? 6 : 166;
			if (my + menuBox.contentHeight > h - n) {
				my = h - n - menuBox.contentHeight;
			}
			
			var p:Point = globalToLocal(new Point(mx, my));
			menuBox.setLayout( { left:p.x, top:p.y } );
			addChild(menuBox);
			menuBox.geometryPhase();
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDownHandler);
		}
		
		public function hideMenu():void {
			if (menuBox) {
				removeChild(menuBox);
				menuBox.dispose();
				menuBox = null;
				menuHandler = null;
				menuData = null;
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDownHandler);
			}
		}
		
		private function onMouseDownHandler(event:MouseEvent):void {
			var obj:DisplayObject = event.target as DisplayObject;
			while (obj) {
				if (obj == menuBox) {
					return;
				}
				obj = obj.parent;
			}
			hideMenu();
		}
		
		private function onClickMenuHandler(event:MouseEvent):void {
			if (menuHandler != null) {
				menuHandler((event.currentTarget as VButton).variance, menuData);
			}
			hideMenu();
		}
		*/

		/**
		 * Задает режим простого просмотра
		 * Задается видимость панель диалогов, юзер панель, инфо и драв панель
		 *
		 * @param 	flag
		 */
		public function useSimpleView(flag:Boolean):void {
			boardPanel.drawPanel.visible = infoPanel.visible = userPanel.visible = dialogPanel.visible = !flag;
		}

		public function getDialogChildIndex():uint {
			return getChildIndex(dialogPanel);
		}
		
	} //end class
}