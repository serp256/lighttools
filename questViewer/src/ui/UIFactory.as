package ui {
	import flash.display.FrameLabel;
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.filters.GlowFilter;
	import flash.geom.ColorTransform;
	import ui.vbase.*;
	
	public class UIFactory {
		public static const PT_OK:uint = 0,         //синенькая
			PT_NO:uint = 1,                        //красненькая
			PT_CHOICE:uint = 2,                  //жёлтенькая
			PT_HELP:uint = 3;                    //зелёненькая

		public static const
			ITEM_BLUE_BG:String = 'ShopItemBlueBg',
			ITEM_YELLOW_BG:String = 'ShopItemYellowBg',
			ITEM_MIGNON_BG:String = 'MignonItemBg',
			BLOCK_BG:String = 'PartSectionBg',
			BROWN_BG:String = 'BrownPanelBg',
			//WR_BG:String = 'WrItemBg',
			G_CHECK:String = 'GreenCheck';
		
		/**
		 * Создать кнопку
		 * Универсальный метод
		 * 
		 * @param	skin				Скин
		 * @param	skinLayout			Layout-скина
		 * @param	icon				Иконка
		 * @param	iconLayout			Layout-иконки
		 * @param	changeStateFunc
		 * @return
		 */
		public static function createButton(skin:VBaseComponent, skinLayout:Object = null, icon:VBaseComponent = null, iconLayout:Object = null, changeStateFunc:Function = null):VButton {
			var bt:VButton = new VButton();
			if (skin) {
				bt.setSkin(skin, skinLayout);
			}
			if (icon) {
				bt.setIcon(icon, iconLayout);
			}
			bt.changeStateFunc = (changeStateFunc != null) ? changeStateFunc : defaultButtonChangeState;
			return bt;
		}
		
		/**
		 * Создать кнопку на базе embed-скина
		 * Кнопка принимает размер скина
		 * 
		 * @param	skinName			Имя скина
		 * @param	skinMode			Режим скина
		 * @param	icon				Иконка
		 * @param	iconLayout			Layout-иконки
		 * @param	changeStateFunc
		 * @return
		 */
		public static function createEmbedButton(skinName:String, skinMode:uint = 0, icon:VBaseComponent = null, iconLayout:Object = null, changeStateFunc:Function = null):VButton {
			var skin:VSkin = AssetManager.getEmbedSkin(skinName, skinMode);
			var bt:VButton = new VButton();
			var layout:VLayout = bt.getLayout();
			layout.w = skin.contentWidth;
			layout.h = skin.contentHeight;
			bt.setSkin(skin, { w:'100%', h:'100%' } );
			if (icon) {
				bt.setIcon(icon, iconLayout);
			}
			bt.changeStateFunc = (changeStateFunc != null) ? changeStateFunc : defaultButtonChangeState;
			return bt;
		}
		
		/*private static function createPreccTextButton(text:String, type:uint, minW:uint, maxW:uint, layoutH:uint, fontSize:uint):PressButton {
			var bt:PressButton = new PressButton(fontSize);
			changePressButtonType(bt, type);
			var layout:VLayout = bt.getLayout();
			layout.minW = minW;
			layout.maxW = maxW;
			layout.minH = layoutH;
			layout.h = layoutH;
			bt.caption = text;
			bt.changeStateFunc = defaultButtonChangeState;
			return bt;
		}
		
		public static function changePressButtonType(bt:PressButton, type:uint):void {
			switch (type) {
				case PT_NO:
					var skinName:String = 'NoButtonBg';
					var glowColor:uint = 0x720000;
					break;
					
				case PT_CHOICE:
					skinName = 'ChoiceButtonBg';
					glowColor = Style.purpleRGB;
					break;
					
				case PT_HELP:
					skinName = 'HelpButtonBg';
					glowColor = 0x192D72;
					break;
					
				default:
					skinName = 'OkButtonBg';
					glowColor = 0x192D72;
			}
			bt.applyType(skinName, glowColor);
		} */
		
		/**
		 * Создает нажимаемую кнопку высотой 24px
		 * 
		 * @param	text			Текст
		 * @param	type			Цветовой тип кнопки - одна из констант UIFactory.PT_...
		 * @param	minW			Минимальная ширина
		 * @param	maxW			Максимальная ширина
		 * @return
		 */
		/*public static function createPressBtH28(text:String, type:uint = 0, minW:uint = 70, maxW:uint = 110):PressButton {
			return createPreccTextButton(text, type, minW, maxW, 28, 14);
		}
		
		public static function createPressBtH36(text:String, type:uint = 0, minW:uint = 100, maxW:uint = 135):PressButton {
			return createPreccTextButton(text, type, minW, maxW, 36, 16);
		}
		
		public static function createPressBtH43(text:String, type:uint = 0, minW:uint = 125, maxW:uint = 165):PressButton {
			return createPreccTextButton(text, type, minW, maxW, 43, 18);
		}*/
		
		public static function createIconButton(icon:VSkin, type:uint = 0, size:uint = 45):VButton {
			switch (type) {
				case PT_NO:
					var skinName:String = 'NoButtonBg';
					break;
					
				case PT_CHOICE:
					skinName = 'ChoiceButtonBg';
					break;
					
				case PT_HELP:
					skinName = 'HelpButtonBg';
					break;
					
				default:
					skinName = 'OkButtonBg';
			}
			var bt:VButton = new VButton();
			var layout:VLayout = bt.getLayout();
			layout.w = size;
			layout.h = size;
			bt.setSkin(AssetManager.getEmbedSkin(skinName, VSkin.STRETCH), { w:'100%', h:'100%' } );
			bt.icon = icon;
			bt.add(icon, { left:5, right:5, top:7, bottom:6 } );
			bt.changeStateFunc = defaultButtonChangeState;
			
			return bt;
		}
		
		public static function defaultButtonChangeState(bt:VButton, newState:uint, oldState:uint):void {
			if (newState == VButton.DISABLED) {
				bt.filters = [Style.GREY_FILTER];
			} else {
				bt.filters = null;
				if (newState == VButton.DOWN) {
					bt.transform.colorTransform = new ColorTransform(.9, .9, .9);
				} else {
					bt.transform.colorTransform = new ColorTransform();
					if (newState == VButton.OVER) {
						bt.filters = [Style.CONTRAST_FILTER];
					}
				}
			}
		}
		
		public static function takeButtonChangeState(bt:VButton, newState:uint, oldState:uint):void {
			if (bt.skin) {
				bt.skin.filters = (newState == VButton.OVER) ? [new GlowFilter(0xFFFF00, 1, 6, 6, 6, 1)] : null;
			}
		}
		
		/**
		 * и подсветить и анимировать кнопку
		 * @param	bt
		 * @param	newState
		 * @param	oldState
		 * @param	isPlay
		 */
	/*	public static function animChangeState(bt:VButton, newState:uint, oldState:uint, isPlay:Boolean = false):void {
			animMcButtonChangeState(bt, newState, oldState);
			defaultButtonChangeState(bt, newState, oldState);
		}*/
		
		public static function mcButtonChangeState(bt:VButton, newState:uint, oldState:uint, isPlay:Boolean = false):void {
			if (bt.skin is VSkin) {
				var mc:MovieClip = (bt.skin as VSkin).content as MovieClip;
			}
			if (!mc) {
				return;
			}
			if (oldState == VButton.DISABLED) {
				bt.filters = null;
			}
			switch (newState) {
				case VButton.DOWN:
					frame = '_down';
					break;

				case VButton.OVER:
					frame = '_over';
					break;

				case VButton.DISABLED:
					isPlay = false;
					var frame:String = '_disable';
					var flag:Boolean;
					for each (var frameLabel:FrameLabel in mc.currentLabels) {
						if (frameLabel.name == frame) {
							flag = true;
							break;
						}
					}
					if (!flag) { //если нет такого кадра, то используем фильтр и _up
						bt.filters = [Style.GREY_FILTER];
					} else {
						break;
					}

				default:
					frame = '_up';
			}
			if (isPlay) {
				mc.gotoAndPlay(frame);
			} else {
				mc.gotoAndStop(frame);
			}
		}
		
		public static function animMcButtonChangeState(bt:VButton, newState:uint, oldState:uint):void {
			mcButtonChangeState(bt, newState, oldState, true);
		}
		
		public static function pressMcButtonChangeState(bt:VButton, newState:uint, oldState:uint):void {
			if (oldState == VButton.DOWN && bt.icon) {
				bt.icon.y -= 2;
			}
			mcButtonChangeState(bt, newState, oldState);
			if (newState == VButton.DOWN && bt.icon) {
				bt.icon.y += 2;
			}
		}
		
		/*
		public static function createScrollBar():VScrollBar {
			return new VScrollBar(
				createButton('ScrollUpButtonSkin'),
				createButton('ScrollDownButtonSkin'),
				AssetManager.getEmbedSkin('ThumbSkin', VSkin.STRETCH),
				AssetManager.getEmbedSkin('TrackSkin', VSkin.STRETCH), 14
			);
		}
		*/
		
		/**
		 * Надпись для заголовков диалога
		 * 
		 * @param			text			Текст
		 * @param			mode			Режим VLabel
		 * @param           fontSize        Размер шрифта
		 * @return
		 */
		public static function createTitle(text:String, mode:uint = 0, fontSize:uint = 34):VLabel {

			var label:VLabel = new VLabel(null, mode);

			if (text) {
				changeTitleText(label, text, fontSize);
			}
			Style.applyHeaderFilter(label, true);
			return label;
		}
		
		public static function changeTitleText(label:VLabel, text:String, fontSize:uint):void {
			label.text = '<div fontSize="' + fontSize + '"' + Style.dialogHeaderText + '>' + text.replace(/ /g, '  ') + '</div>';
		}
		
		/**
		 * Однострочный заголовочный текст
		 * 
		 * @param	text       Текст
		 * @param	mode       Режим VLabel
		 * @return
		 */
		public static function createHeaderLabel(text:String, mode:uint = 0):VLabel {
			var label:VLabel = new VLabel(text ? '<p' + Style.headerText + '>' + text + '</p>' : null, mode);
			Style.applyBigTitleGlow(label, Style.purpleRGB);
			return label;
		}
		
		public static function createCheckbox(text:String, selected:Boolean = false, fontSize:uint = 14):VCheckbox {
			var boxSkin:VSkin = AssetManager.getEmbedSkin('ChBox');
			boxSkin.setLayout( { vCenter:0 } );
			
			var checkSkin:VSkin = AssetManager.getEmbedSkin('ChCheck');
			checkSkin.setLayout( { left:4, vCenter:0 } );
			
			var label:VLabel = new VLabel('<div' + Style.brownColor + ' fontSize="' + fontSize + '">' + text + '</div>', VLabel.VERTICAL_MIDDLE);
			label.setLayout( { left:30, right:0, h:'100%' } );
			
			return new VCheckbox(boxSkin, checkSkin, label, selected);
		}

		
	/*	
		public static function createCompactCheckbox(text:String, selected:Boolean = false):VCheckbox {
			return new VCheckbox(
                AssetManager.getEmbedSkin('ChBox', VSkin.STRETCH_CONTAIN, 18, 18),
                AssetManager.getEmbedSkin('ChCheck'), { vCenter:-3, left:1, w:18, h:18 },
                '<div' + Style.brownColor + ' paddingLeft="2" fontSize="12">' + text + '</div>',
				selected
            );
		}
		*/
		
		/**
		 * Создать кнопку навигации
		 * 
		 * @param	flip			Отображать зеркально (false - стрелка повернута влево, true - стрелка повернуто вправо)
		 * @param	isVertical		Вертикальный режим
		 * @param	isStretch		Режим растежения: true - VSkin.STRETCH, false - VSkin.STRETCH_CONTAIN
		 * @return
		 */
		public static function createNavButton(flip:Boolean, isVertical:Boolean = false, isStretch:Boolean = false):VButton {
			if (isStretch) {
				var mode:uint = VSkin.STRETCH;
			}
			if (isVertical) {
				mode |= VSkin.ROTATE_90;
				if (flip) {
					mode |= VSkin.FLIP_Y;
				}
			} else {
				if (flip) {
					mode |= VSkin.FLIP_X;
				}
			}
			return createEmbedButton('BtNavBg', mode);
		}
		
		public static function createSeparatorSkin(isStrech:Boolean = true):VSkin {
			var skin:VSkin = AssetManager.getEmbedSkin('SeparatorSkin', VSkin.STRETCH);
			if (isStrech) {
				skin.setLayout( { w:'100%' } );
			}
			return skin;
		}
		
		public static function createShopButton(skin:VSkin):VButton {
			return createButton(skin, { w:128, h:128 }, new VSkin(VSkin.NO_STOP_MOVIECLIP | VSkin.CONTAIN), { w:100, h:100, vCenter:0, hCenter:0 } );
		}
		
		public static function addBrownBg(target:VBaseComponent):void {
			target.add(AssetManager.getEmbedSkin(BROWN_BG, VSkin.STRETCH | VSkin.CUSTOM_CONTENT_SIZE), { w:'100%', h:'100%' }, 0);
		}
		
		public static function createInfoLabel(text:String = null, mode:uint = 0):VLabel {
			var label:VLabel = new VLabel(text, mode);
			label.getLayout().w = 186;
			Style.applyTitleGlow(label, Style.purpleRGB);
			return label;
		}
		

		/**
		 * Добавить обучающую стрелку
		 *
		 * @param	component			Компонент
		 * @param	layout				Расположение стрелки
		 * @param	rotation			Угол поворота
		 */
		public static function addArrowLearn(component:VBaseComponent, layout:Object = null, rotation:int = 0):void {
			if (!component) {
				return;
			}
			//если есть слушатель на событие удаления стрелочки, то еще одну стрелку добавлять не будем
			if (component.hasListener(MouseEvent.CLICK, hideArrowLearn)) {
				return;
			}
			var skin:VSkin = createArrowLearn(rotation);
			component.add(skin, layout);

			component.addListener(MouseEvent.CLICK, hideArrowLearn);
		}

		/**
		 * Удаляет обучающую стрелку
		 *
		 * @param	data	MouseEvent.CLICK || VButton
		 */
		public static function hideArrowLearn(data:Object):void {
			var bt:VBaseComponent = ((data is MouseEvent) ? (data as MouseEvent).currentTarget : data) as VBaseComponent;
			if (bt.hasListener(MouseEvent.CLICK, hideArrowLearn)) {
				bt.removeListener(MouseEvent.CLICK, hideArrowLearn);
				bt.remove(bt.getChildAt(bt.numChildren - 1) as VBaseComponent);
			}
		}

		public static function createArrowLearn(rotation:int = 0):VSkin {
			var skin:VSkin = AssetManager.getEmbedSkin('ArrowLearn', VSkin.NO_STOP_MOVIECLIP | VSkin.CUSTOM_CONTENT_SIZE);
			skin.rotation = rotation;
			return skin;
		}

	} //end class
}