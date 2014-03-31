package ui.vtool {
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.ColorTransform;
	import flash.geom.Point;
	import flash.utils.getQualifiedClassName;
	import ui.vbase.*;
	
	public class VToolPanel extends VBaseComponent {
		public static var instance:VToolPanel;
		
		public static const GREY_FILTER:ColorMatrixFilter = new ColorMatrixFilter([
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0, 0, 0, 1, 0
		]);
		public static const CONTRAST_FILTER:ColorMatrixFilter = new ColorMatrixFilter([
			1.28, 0, 0, 0, -17.78,
			0, 1.28, 0, 0, -17.78,
			0, 0, 1.28, 0, -17.78,
			0, 0, 0, 1, 0
		]);
		
		public static function change(stage:Stage, layout:Object):void {
			if (instance) {
				dispose();
			} else {
				init(stage, layout);
			}
		}
		
		public static function init(stage:Stage, layout:Object):void {
			if (instance) {
				return;
			}
			ComponentPanel.target = null;
			stage.addEventListener(Event.RESIZE, onStageResizeHandler);
			instance = new VToolPanel();
			var canvas:VBaseComponent = new VBaseComponent();
			canvas.add(instance, layout);
			stage.addChild(instance.drawSpirte);
			stage.addChild(canvas);
			stage.addChild(instance.layoutPanel).visible = false;
			
			onStageResizeHandler();
		}
		
		public static function dispose():void {
			if (!instance) {
				return;
			}
			var canvas:VBaseComponent = instance.parent as VBaseComponent;
			canvas.stage.removeEventListener(Event.RESIZE, onStageResizeHandler);
			canvas.dispose();
			canvas.stage.removeChild(instance.drawSpirte);
			canvas.stage.removeChild(instance.layoutPanel);
			instance.layoutPanel.dispose();
			canvas.stage.removeChild(canvas);
			instance = null;
		}
		
		public static function getClassName(value:*):String {
			var className:String = getQualifiedClassName(value);
			var index:int = className.lastIndexOf('::');
			return className.substr((index == -1) ? 0 : index + 2, className.length);
		}
		
		public static function drawCounter(target:DisplayObject = null):void {
			var g:Graphics = VToolPanel.instance.drawSpirte.graphics;
			g.clear();
			
			var component:VBaseComponent = target ? target as VBaseComponent : ComponentPanel.target;
			if (component) {
				var p:Point = component.localToGlobal(new Point());
				g.lineStyle(2, 0xFF0000);
				g.drawRect(p.x, p.y, component.w, component.h);
			}
		}
		
		public static function clearCounter():void {
			instance.drawSpirte.graphics.clear();
		}
		
		/**
		 * Обработчик изменения размеров stage
		 * 
		 * @param	event		Объект события Event.RESIZE
		 */
		private static function onStageResizeHandler(event:Event = null):void {
			var canvas:VBaseComponent = instance.parent as VBaseComponent;
			canvas.setGeometrySize(canvas.stage.stageWidth, canvas.stage.stageHeight, true);
		}
		
		private static function defaultButtonChangeState(bt:VButton, newState:uint, oldState:uint):void {
			if (newState == VButton.DISABLED) {
				bt.filters = [GREY_FILTER];
			} else {
				bt.filters = null;
				if (newState == VButton.DOWN) {
					bt.transform.colorTransform = new ColorTransform(.9, .9, .9);
				} else {
					bt.transform.colorTransform = new ColorTransform();
					if (newState == VButton.OVER) {
						bt.filters = [CONTRAST_FILTER];
					}
				}
			}
		}
		
		public static function createTextButton(skinName:String, text:String, listener:Function = null):VButton {
			var bt:VButton = new VButton();
			bt.setSkin(AssetManager.getEmbedSkin(skinName, VSkin.STRETCH), { w:'100%', h:'100%' } );
			bt.changeStateFunc = defaultButtonChangeState;
			var label:VLabel = new VLabel('<div fontSize="16" color="0x591100">' + text + '</div>', VLabel.CENTER | VLabel.CONTAIN);
			bt.icon = label;
			bt.add(label, { left:6, right:6, vCenter:0 } );
			if (listener != null) {
				bt.addListener(MouseEvent.CLICK, listener);
			}
			var layout:VLayout = bt.getLayout();
			layout.w = 90;
			layout.h = 28;
			return bt;
		}
		
		/**
		 * Создает кнопку, размер которой определеяется скином
		 * 
		 * @param	skinName			Имя скина
		 * @param	skinMode
		 * @param	icon				
		 * @param	iconLayout			Layout-иконки
		 * @return
		 */
		public static function createEmbedButton(skinName:String, skinMode:uint = 0, icon:VBaseComponent = null, iconLayout:Object = null):VButton {
			var skin:VSkin = AssetManager.getEmbedSkin(skinName, skinMode);
			var bt:VButton = new VButton();
			var layout:VLayout = bt.getLayout();
			layout.w = skin.contentWidth;
			layout.h = skin.contentHeight;
			bt.setSkin(skin, { w:'100%', h:'100%' } );
			if (icon) {
				bt.icon =  icon;
				bt.add(icon, iconLayout);
			}
			bt.changeStateFunc = defaultButtonChangeState;
			return bt;
		}
		
		public static function createScrollBar():VScrollBar {
			var trackSkin:VSkin = AssetManager.getEmbedSkin('VToolTrack', VSkin.STRETCH);
			trackSkin.setLayout( { minH:30, h:'100%' } );
			var thumbSkin:VSkin = AssetManager.getEmbedSkin('VToolThumb', VSkin.STRETCH);
			thumbSkin.setLayout( { hCenter:0, minH:14 } );
			return new VScrollBar(
				createEmbedButton('VToolScrollButton'),
				createEmbedButton('VToolScrollButton', VSkin.FLIP_Y),
				trackSkin,
				thumbSkin
			);
		}
		
		public static function createCheckbox(text:String, selected:Boolean = false):VCheckbox {
			var boxSkin:VSkin = AssetManager.getEmbedSkin('VToolEmptyCkeckbox');
			boxSkin.setLayout( { w:14, h:14, vCenter:0 } );
			var checkSkin:VSkin = AssetManager.getEmbedSkin('VToolCheckLabel');
			checkSkin.setLayout( { left:2, vCenter:-2 } );
			if (text) {
				var label:VLabel = new VLabel(text, VLabel.VERTICAL_MIDDLE);
				label.setLayout( { left:16, h:'100%' } );
			}
			return new VCheckbox(boxSkin, checkSkin, label, selected);
		}
		
		private var btCapture:VButton = createTextButton('VToolBlueButtonBg2', 'Захват', onChangeTabHandler);
		private var btComponent:VButton = createTextButton('VToolBlueButtonBg2', 'Компонент', onChangeTabHandler);
		private var capturePanel:CapturePanel = new CapturePanel();
		private var componentPanel:ComponentPanel = new ComponentPanel();
		public var drawSpirte:Sprite = new Sprite();
		public var layoutPanel:LayoutPanel = new LayoutPanel();
		
		public function VToolPanel():void {
			layout.w = 200;
			layout.h = 220;
			
			graphics.beginFill(0xFCFDEE);
			graphics.lineStyle(1, 0x353A55, .57, true);
			graphics.drawRoundRect(0, 0, layout.w, layout.h, 15);
			
			add(btCapture, { left:5, top:5 } );
			add(btComponent, { left:100, top:5 } );
			onChangeTabHandler(btCapture);
		}
		
		/**
		 * Обработчик смены вкладки
		 * 
		 * @param	event		Объект события MouseEvent.CLICK
		 */
		private function onChangeTabHandler(data:Object):void {
			var bt:VButton = ((data is MouseEvent) ? (data as MouseEvent).currentTarget : data) as VButton;
			bt.disabled = true;
			
			if (bt == btCapture) {
				if (componentPanel.parent) {
					remove(componentPanel, false);
				}
				btComponent.disabled = false;
				var panel:VBaseComponent = capturePanel;
			} else {
				if (capturePanel.parent) {
					remove(capturePanel, false);
				}
				btCapture.disabled = false;
				panel = componentPanel;
			}
			add(panel, { left:5, right:5, top:37, bottom:5 } );
			
			if (panel == componentPanel) {
				clearCounter();
				componentPanel.update();
			} else {
				if (ComponentPanel.target) {
					ComponentPanel.target.showRegion(false);
					drawCounter();
				}
			}
		}
		
	} //end class
}