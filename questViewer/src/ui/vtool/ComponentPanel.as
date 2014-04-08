package ui.vtool {
	import flash.net.*;
	import ui.GridConnector;
	import ui.Style;
	import ui.vbase.*;
	import utils.ULoader;
	
	public class ComponentPanel extends VBaseComponent {
		public static var target:VBaseComponent;
		
		private var curTarget:VBaseComponent;
		private var cbRegion:VCheckbox = VToolPanel.createCheckbox('<p color="0x591100" fontSize="12">область</p>', true);
		private var cbTen:VCheckbox = VToolPanel.createCheckbox('<p color="0x591100" fontSize="12">10</p>');
		private var cbHundred:VCheckbox = VToolPanel.createCheckbox('<p color="0x591100" fontSize="12">100</p>');
		private var gridConnector:GridConnector;
		private var lbInfo:VLabel = new VLabel();
		
		public function ComponentPanel():void {
			addChild(cbRegion);
			cbRegion.addListener(VEvent.CHANGE, onRegionHandler);
			add(new VBox(new <VBaseComponent>[cbHundred, cbTen], false), { right:0 } );
			cbTen.addListener(VEvent.CHANGE, onChangeDigitBtValueHandler);
			cbHundred.addListener(VEvent.CHANGE, onChangeDigitBtValueHandler);
			add(lbInfo, { left:2, right:2, top:20 } );
			
			var gridPanel:VGridPanel = new VGridPanel(1, 7, ComponentItemRenderer, null, 0, 2, VGridPanel.H_STREACH | VGridPanel.DRIFT_INDEX);
			var scroll:VScrollBar = VToolPanel.createScrollBar();
			scroll.setLayout( { h:'100%' } );
			gridPanel.setLayout( { w:'100%' } );
			add(new VBox(new <VBaseComponent>[gridPanel, scroll], false, 2), { w:'100%', top:38 } );
			gridConnector = GridConnector.createWithScroll(gridPanel, scroll);
			
			gridPanel.addListener(VEvent.SELECT, onSelectHandler);
		}
		
		public function update(key:String = null):void {
			if (key == null && cbRegion.selected) {
				onRegionHandler(null);
			}
			
			if (curTarget == target) {
				if (key) {
					var index:uint = gridConnector.index;
				} else {
					return;
				}
			} else {
				index = 0;
				curTarget = target;
				updateInfo();
			}
			
			var layout:VLayout = curTarget.getLayout();
			var dpList:Array = [
				new VOComponentItem('left', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, (layout.left != int.MIN_VALUE) ? layout.left : 0, layout.left != int.MIN_VALUE),
				new VOComponentItem('right', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, (layout.right != int.MIN_VALUE) ? layout.right : 0, layout.right != int.MIN_VALUE),
				new VOComponentItem('top', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, (layout.top != int.MIN_VALUE) ? layout.top : 0, layout.top != int.MIN_VALUE),
				new VOComponentItem('bottom', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, (layout.bottom != int.MIN_VALUE) ? layout.bottom : 0, layout.bottom != int.MIN_VALUE),
				new VOComponentItem('vCenter', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, layout.vCenter, layout.isVCenter),
				new VOComponentItem('hCenter', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, layout.hCenter, layout.isHCenter),
				new VOComponentItem('w', VOComponentItem.DIGIT, layout.w),
				new VOComponentItem('w%', VOComponentItem.CHECKBOX, null, layout.isWPercent),
				new VOComponentItem('h', VOComponentItem.DIGIT, layout.h),
				new VOComponentItem('h%', VOComponentItem.CHECKBOX, null, layout.isHPercent)
			];
			if (target is VLabel) {
				addVLabelProp(dpList, target as VLabel);
			} else if (target is VSkin) {
				addVSkinProp(dpList, target as VSkin);
			} else if (target is VBox) {
				addVBoxProp(dpList, target as VBox);
			} else if (target is VGridPanel) {
				addVGridPanelProp(dpList, target as VGridPanel);
			} else if (target is VProgressBar) {
				dpList.unshift(
					new VOComponentItem('pb_value', VOComponentItem.DIGIT, Math.round((target as VProgressBar).value * 100))
				);
			}
			
			gridConnector.changeDp(dpList, index);
			
			if (key) {
				for each (var renderer:ComponentItemRenderer in gridConnector.getGridPanel().renders) {
					if (key == renderer.item.key) {
						renderer.setSelection();
						break;
					}
				}
			}
		}
		
		private function addVLabelProp(dpList:Array, label:VLabel):void {
			var mode:uint = label.getMode();
			var str:String = label.tlfText;
			if (str) {
				str = str.replace('\n', '');
			}
			
			dpList.unshift(
				new VOComponentItem('lb_text', VOComponentItem.TEXT, str),
				new VOComponentItem('lb_contain', VOComponentItem.CHECKBOX, null, (mode & VLabel.CONTAIN) != 0, VLabel.CONTAIN),
				new VOComponentItem('lb_middle', VOComponentItem.CHECKBOX, null, (mode & VLabel.VERTICAL_MIDDLE) != 0, VLabel.VERTICAL_MIDDLE),
				new VOComponentItem('lb_center', VOComponentItem.CHECKBOX, null, (mode & VLabel.CENTER) != 0, VLabel.CENTER)
			);
			
			str = label.text;
			if (str) {
				if (str.charAt() == '#') {
					var raw:String = str.substr(1);
				} else {
					var lexicon:Object = Lang.lexicon;
					for (var kind:String in lexicon) {
						if (lexicon[kind] == str) {
							raw = kind;
							break;
						}
					}
				}
			}
			if (raw) {
				dpList.unshift(
					new VOComponentItem('lb_kind', VOComponentItem.INFO, raw),
					new VOComponentItem('lb_s_text', VOComponentItem.TEXT, label.text),
					new VOComponentItem('lb_save', VOComponentItem.BUTTON, raw)
				);
			}
		}
		
		private function addVSkinProp(dpList:Array, skin:VSkin):void {
			var mode:uint = skin.getMode();
			dpList.unshift(
				new VOComponentItem('s_stretch', VOComponentItem.CHECKBOX, null, (mode & VSkin.STRETCH) != 0, VSkin.STRETCH),
				new VOComponentItem('s_contain', VOComponentItem.CHECKBOX, null, (mode & VSkin.CONTAIN) != 0, VSkin.CONTAIN),
				new VOComponentItem('s_no_stretch', VOComponentItem.CHECKBOX, null, (mode & VSkin.NO_STRETCH) != 0, VSkin.NO_STRETCH),
				new VOComponentItem('s_left', VOComponentItem.CHECKBOX, null, (mode & VSkin.LEFT) != 0, VSkin.LEFT),
				new VOComponentItem('s_top', VOComponentItem.CHECKBOX, null, (mode & VSkin.TOP) != 0, VSkin.TOP)
			);
		}
		
		private function addVGridPanelProp(dpList:Array, gridPanel:VGridPanel):void {
			dpList.unshift(
				new VOComponentItem('g_column', VOComponentItem.DIGIT, gridPanel.numColumn),
				new VOComponentItem('g_row', VOComponentItem.DIGIT, gridPanel.numRow),
				new VOComponentItem('g_hgap', VOComponentItem.DIGIT, gridPanel.hgap),
				new VOComponentItem('g_vgap', VOComponentItem.DIGIT, gridPanel.vgap)
			);
		}
		
		private function addVBoxProp(dpList:Array, box:VBox):void {
			dpList.unshift(
				new VOComponentItem('box_gap', VOComponentItem.DIGIT, box.gap),
				new VOComponentItem('box_align', VOComponentItem.DIGIT, box.align)
			);
		}
		
		private function onSelectHandler(event:VEvent):void {
			var layout:VLayout = curTarget.getLayout();
			
			var item:VOComponentItem = event.data as VOComponentItem;
			var isSyncProperty:Boolean; //изменение свойства влечет изменение других данных
			
			switch (item.key) {
				case 'left':
				case 'right':
					layout[item.key] = item.checkbox ? int(item.value) : int.MIN_VALUE;
					layout.isHCenter = false;
					
					if (layout.right != int.MIN_VALUE && layout.left != int.MIN_VALUE && layout.isWPercent) {
						layout.isWPercent = false;
						isSyncProperty = true;
					}
					if (layout.isHCenter) {
						layout.isHCenter = false;
						isSyncProperty = true;
					}
					break;
					
				case 'top':
				case 'bottom':
					layout[item.key] = item.checkbox ? int(item.value) : int.MIN_VALUE;
					layout.isVCenter = false;
					
					if (layout.top != int.MIN_VALUE && layout.bottom != int.MIN_VALUE && layout.isHPercent) {
						layout.isHPercent = false;
						isSyncProperty = true;
					}
					if (layout.isVCenter) {
						layout.isVCenter = false;
						isSyncProperty = true;
					}
					break;
					
				case 'w':
					layout.w = getUInt(item.value);
					break;
					
				case 'w%':
					layout.isWPercent = item.checkbox;
					break;
					
				case 'h':
					layout.h = getUInt(item.value);
					break;
					
				case 'h%':
					layout.isHPercent = item.checkbox;
					break;
					
				case 'vCenter':
					layout.vCenter = int(item.value);
					layout.isVCenter = item.checkbox;
					if (layout.isVCenter && (layout.top != int.MIN_VALUE || layout.bottom != int.MIN_VALUE)) {
						layout.top = int.MIN_VALUE;
						layout.bottom = int.MIN_VALUE;
						isSyncProperty = true;
					}
					break;
					
				case 'hCenter':
					layout.hCenter = int(item.value);
					layout.isHCenter = item.checkbox;
					if (layout.isHCenter && (layout.left != int.MIN_VALUE || layout.right != int.MIN_VALUE)) {
						layout.left = int.MIN_VALUE;
						layout.right = int.MIN_VALUE;
						isSyncProperty = true;
					}
					break;
					
				default:
					var isSkipLayout:Boolean = true;
					
			} //end switch
			
			if (!isSkipLayout) {
				curTarget.syncLayout();
			}
			
			switch (item.key) {
				case 's_stretch':
				case 's_contain':
				case 's_no_stretch':
				case 's_left':
				case 's_top':
					var mode:uint = (curTarget as VSkin).getMode();
					if (item.checkbox) {
						mode |= item.bit;
					} else {
						mode &= ~item.bit;
					}
					(curTarget as VSkin).setMode(mode);
					break;
					
				case 'lb_text':
					(curTarget as VLabel).text = item.value as String;
					syncInputText('lb_s_text', (curTarget as VLabel).text);
					break;
					
				case 'lb_s_text':
					applyLabelSimpleText(curTarget as VLabel, item.value as String);
					break;
					
				case 'lb_save':
					changeLang(curTarget as VLabel, item);
					break;
					
				case 'lb_contain':
				case 'lb_middle':
				case 'lb_center':
					mode = (curTarget as VLabel).getMode();
					if (item.checkbox) {
						mode |= item.bit;
					} else {
						mode &= ~item.bit;
					}
					(curTarget as VLabel).setMode(mode);
					break;
					
				case 'g_column':
					(curTarget as VGridPanel).changeRendererCount(getUInt(item.value), (curTarget as VGridPanel).numRow);
					break;
					
				case 'g_row':
					(curTarget as VGridPanel).changeRendererCount((curTarget as VGridPanel).numColumn, getUInt(item.value));
					break;
					
				case 'g_hgap':
					(curTarget as VGridPanel).hgap = getUInt(item.value);
					break;
					
				case 'g_vgap':
					(curTarget as VGridPanel).vgap = getUInt(item.value);
					break;
					
				case 'box_gap':
					(curTarget as VBox).gap = getUInt(item.value);
					break;
					
				case 'pb_value':
					(curTarget as VProgressBar).value = getUInt(item.value) / 100;
					break;
			}
			
			updateInfo();
			if (cbRegion.selected) {
				onRegionHandler();
			}
			if (isSyncProperty) {
				update(item.key);
			}
		}
		
		private function getUInt(value:*):uint {
			if (value is String) {
				value = Number(value);
			}
			if (value is uint) {
				return value as uint;
			} else if (value is Number) {
				var n:Number = value as Number;
				if (!isNaN(n) && n > 0) {
					return n;
				}
			} else if (value is int) {
				var i:int = value as int;
				if (i > 0) {
					return i;
				}
			}
			return 0;
		}
		
		private function updateInfo():void {
			var str:String = '<p color="0x591100" fontSize="12">' + curTarget.w + 'x' + curTarget.h + ' (' + curTarget.x + ',' + curTarget.y + ')';
			if (curTarget is VBox) {
				str += ' len=' + (curTarget as VBox).list.length;
			}
			lbInfo.text = str + '</p>';
		}
		
		private function onRegionHandler(event:VEvent = null):void {
			if (event) {
				VToolPanel.instance.layoutPanel.visible = false;
			}
			if (target) {
				target.showRegion(event ? event.data : true, 0x009900, 1, false);
			}
		}
		
		/*
		private function onLayoutHandler(event:VEvent):void {
			cbRegion.selected = false;
			if (curTarget) {
				curTarget.showRegion(false);
				var lp:LayoutPanel = VToolPanel.instance.layoutPanel;
				lp.visible = true;
				lp.setGeometrySize(curTarget.w, curTarget.h, false);
				var p:Point = curTarget.localToGlobal(new Point());
				lp.x = p.x;
				lp.y = p.y;
			}
		}
		*/
		
		/**
		 * Обработчик изменения режима ввода числовых значний через кнопки
		 * 
		 * @param	event		Объект события VEvent.CHANGE (cbTen)
		 */
		private function onChangeDigitBtValueHandler(event:VEvent):void {
			if (event.data) {
				if (event.currentTarget == cbHundred) {
					cbTen.selected = false;
					var value:uint = 100;
				} else {
					cbHundred.selected = false;
					value = 10;
				}
			} else {
				value = 1;
			}
			ComponentItemRenderer.digitBtValue = value;
		}
		
		private function syncInputText(key:String, value:String):void {
			for each (var renderer:ComponentItemRenderer in gridConnector.getGridPanel().renders) {
				if (renderer.item.key == key) {
					renderer.setInputText(value);
					break;
				}
			}
		}
		
		private function applyLabelSimpleText(label:VLabel, text:String):void {
			var tlf:String = label.tlfText;
			var i:int = tlf.indexOf('<span>');
			if (i >= 0) {
				var j:int = tlf.indexOf('</span>', i);
				if (j > 0) {
					text = tlf.substr(0, i) + text + tlf.substr(j + 7);
					label.text = text;
					syncInputText('lb_text', text);
				}
			}
		}
		
		private function changeLang(label:VLabel, item:VOComponentItem):void {
			AppFacade.mainMediator.showYesNoAlert('Изменение ланга', null,
				'Для ключа <span' + Style.purpleColor + '>' + item.value + '</span> будет задан текст:\n<span' +
					Style.redColor + '>' + label.text + '</span>',
				saveLang, [label.text, item.value], skipSaveLang
			);
			VToolPanel.instance.visible = false;
		}
		
		private function saveLang(text:String, kind:String):void {
			VToolPanel.instance.visible = true;

			var request:URLRequest = new URLRequest('http://ns1.inventos.ru:8189/evil/fix_phrase');
			request.method = URLRequestMethod.POST;
			var variables:URLVariables = new URLVariables();
            variables.key = kind;
			variables.vl = text;
			variables.hohoho = '1';
            request.data = variables;
			var loader:ULoader = new ULoader(null);
			loader.load(request);
			
			Lang.lexicon[kind] = text;
		}

		private function skipSaveLang():void {
			VToolPanel.instance.visible = true;
		}
		
	} //end class
}
