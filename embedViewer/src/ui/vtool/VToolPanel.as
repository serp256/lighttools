package ui.vtool {
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.utils.getQualifiedClassName;

	import ui.vbase.SkinManager;
	import ui.vbase.VButton;
	import ui.vbase.VCheckbox;
	import ui.vbase.VComponent;
	import ui.vbase.VInputText;
	import ui.vbase.VLabel;
	import ui.vbase.VScrollBar;
	import ui.vbase.VSkin;

	public class VToolPanel extends VComponent {
		public static var instance:VToolPanel;
		private static var keyCode:uint;

		public static function assign(stage:Stage, keyCode:uint = 86):void {
			VToolPanel.keyCode = keyCode;
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		}

		public static function clear(stage:Stage):void {
			dispose();
			stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		}

		private static function onKeyDown(event:KeyboardEvent):void {
			if (event.target.parent is VInputText) {
				return;
			}

			if (event.keyCode == keyCode) {
				if (instance) {
					dispose();
				} else {
					init(event.currentTarget as Stage);
				}
			} else if (instance) {
				if (event.ctrlKey && event.altKey) {
					switch (event.keyCode) {
						case 37: //left
							var obj:Object = { left:10, vCenter:0 };
							break;

						case 39: //right
							obj = { right:10, vCenter:0 };
							break;

						case 38: //top
							obj = { top:10, hCenter:0 };
							break;

						case 40: //bottom:
							obj = { bottom:10, hCenter:0 };
							break;
					}
					if (obj) {
						obj.w = instance.layoutW;
						obj.h = instance.layoutH;
						instance.resetLayout();
						instance.assignLayout(obj);
						instance.syncLayout();
					}
				}
			}
		}

		private static function init(stage:Stage):void {
			if (instance) {
				return;
			}
			ComponentPanel.target = null;
			stage.addEventListener(Event.RESIZE, onStageResize);
			instance = new VToolPanel();
			var canvas:VComponent = new VComponent();
			canvas.add(instance, { right:10, vCenter:0 });
			stage.addChild(instance.drawSprite);
			stage.addChild(instance.layoutPanel).visible = false;
			stage.addChild(canvas);

			onStageResize();
			instance.capturePanel.onTarget();
		}

		private static function dispose():void {
			if (!instance) {
				return;
			}
			var canvas:VComponent = instance.parent as VComponent;
			canvas.stage.removeEventListener(Event.RESIZE, onStageResize);
			canvas.dispose();
			canvas.stage.removeChild(instance.drawSprite);
			instance.layoutPanel.dispose();
			canvas.stage.removeChild(instance.layoutPanel);
			canvas.stage.removeChild(canvas);
			instance = null;
		}

		public static function getClassName(value:*):String {
			var className:String = getQualifiedClassName(value);
			var index:int = className.lastIndexOf('::');
			return className.substr((index == -1) ? 0 : index + 2, className.length);
		}

		public static function drawCounter(target:DisplayObject = null, isGreen:Boolean = false):void {
			var g:Graphics = VToolPanel.instance.drawSprite.graphics;
			g.clear();

			var component:VComponent = target ? target as VComponent : ComponentPanel.target;
			if (component) {
				if (isGreen) {
					g.lineStyle(1, 0x009900);
				} else {
					g.lineStyle(2, 0xFF0000);
				}
				var p:Point = component.localToGlobal(new Point());
				g.drawRect(p.x, p.y, component.w, component.h);
			}
		}

		public static function clearCounter():void {
			instance.drawSprite.graphics.clear();
		}

		/**
		 * Обработчик изменения размеров stage
		 *
		 * @param    event        Объект события Event.RESIZE
		 */
		private static function onStageResize(event:Event = null):void {
			var canvas:VComponent = instance.parent as VComponent;
			canvas.setGeometrySize(canvas.stage.stageWidth, canvas.stage.stageHeight, true);
		}

		public static function createTextButton(text:String, listener:Function = null, skinName:String = 'Green'):VButton {
			var bt:VButton = new VButton();
			bt.setSkin(SkinManager.getEmbed('VTool' + skinName+'ButtonBg', VSkin.STRETCH), { wP:100, hP:100 });
			var label:VLabel = new VLabel('<div fontFamily="Myriad Pro" fontSize="16" color="0x000055">' + text + '</div>', VLabel.CENTER | VLabel.CONTAIN);
			bt.icon = label;
			bt.add(label, { left:6, right:6, vCenter:0 });
			if (listener != null) {
				bt.addListener(MouseEvent.CLICK, listener);
			}
			bt.setSize(90, 28);
			return bt;
		}

		/**
		 * Создает кнопку, размер которой определеяется скином
		 *
		 * @param    skinName            Имя скина
		 * @param    skinMode
		 * @param    icon
		 * @param    iconLayout          Layout-иконки
		 * @return
		 */
		public static function createEmbedButton(skinName:String, skinMode:uint = 0, icon:VComponent = null, iconLayout:Object = null):VButton {
			var skin:VSkin = SkinManager.getEmbed(skinName, skinMode);
			var bt:VButton = new VButton();
			bt.setSize(skin.measuredWidth, skin.measuredHeight);
			bt.setSkin(skin);
			skin.stretch();
			if (icon) {
				bt.icon = icon;
				bt.add(icon, iconLayout);
			}
			return bt;
		}

		public static function createScrollBar():VScrollBar {
			var track:VSkin = SkinManager.getEmbed('VToolTrack', VSkin.STRETCH);
			var thumb:VButton = createEmbedButton('VToolThumb', VSkin.STRETCH);
			var downBt:VButton = createEmbedButton('VToolScrollButton', VSkin.FLIP_Y);
			var upBt:VButton = createEmbedButton('VToolScrollButton');
			var sb:VScrollBar = new VScrollBar(track, thumb, VScrollBar.WHEEL);
			sb.assignButton(upBt, downBt);
			sb.minH = 60;
			sb.add(track, { hCenter:0, top:12, bottom:12 });
			sb.addChild(upBt);
			sb.add(downBt, { bottom:0 });
			sb.add(thumb, { hCenter:0, minH:14, top:12, bottom:12 });
			return sb;
		}

		public static function createCheckbox(text:String, selected:Boolean = false):VCheckbox {
			var boxSkin:VSkin = SkinManager.getEmbed('VToolEmptyCkeckbox');
			boxSkin.assignLayout({ w:14, h:14, vCenter:0 });
			var checkSkin:VSkin = SkinManager.getEmbed('VToolCheckLabel');
			checkSkin.assignLayout({ left:2, vCenter:-2 });
			if (text) {
				var label:VLabel = new VLabel(text, VLabel.MIDDLE);
				label.assignLayout({ left:16, hP:100 });
			}
			return new VCheckbox(boxSkin, checkSkin, label, selected);
		}

		public static function createInputText(fontSize:uint = 12, color:uint = 0xFF0000, mode:uint = 0, paddingH:uint = 6, paddingV:uint = 3):VInputText {
			var inputText:VInputText = new VInputText(mode, SkinManager.getEmbed('VToolBgInputText', VSkin.STRETCH), paddingH, paddingV);
			inputText.setBaseFormat(fontSize, color);
			inputText.format.fontFamily = 'Myriad Pro';
			return inputText;
		}

		public const
			captureBt:VButton = createTextButton('Захват', onChangeTab, 'Blue'),
			componentBt:VButton = createTextButton('Компонент', onChangeTab, 'Blue'),
			capturePanel:CapturePanel = new CapturePanel(),
			componentPanel:ComponentPanel = new ComponentPanel(),
			drawSprite:Sprite = new Sprite(),
			layoutPanel:LayoutPanel = new LayoutPanel()
			;

		public function VToolPanel() {
			setSize(200, 220);

			graphics.beginFill(0xFCFDEE);
			graphics.lineStyle(1, 0x353A55, .57, true);
			graphics.drawRoundRect(0, 0, layoutW, layoutH, 15);

			add(captureBt, { left:5, top:5 });
			add(componentBt, { left:100, top:5 });
			onChangeTab(captureBt);
		}

		/**
		 * Обработчик смены вкладки
		 *
		 * @param    data        Объект события MouseEvent.CLICK || VButton
		 */
		public function onChangeTab(data:Object):void {
			var bt:VButton = ((data is MouseEvent) ? (data as MouseEvent).currentTarget : data) as VButton;
			bt.disabled = true;

			if (bt == captureBt) {
				if (componentPanel.parent) {
					remove(componentPanel, false);
				}
				componentBt.disabled = false;
				var panel:VComponent = capturePanel;
			} else {
				if (capturePanel.parent) {
					remove(capturePanel, false);
				}
				captureBt.disabled = false;
				panel = componentPanel;
			}
			add(panel, { left:5, right:5, top:37, bottom:5 });

			if (ComponentPanel.target) {
				if (panel == componentPanel) {
					clearCounter();
					componentPanel.update(null, true);
				} else {
					layoutPanel.assign(null);
					drawCounter();
				}
			}
		}

	} //end class
}