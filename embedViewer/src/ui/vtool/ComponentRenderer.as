package ui.vtool {
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;

	import flashx.textLayout.formats.TextLayoutFormat;

	import ui.vbase.VBox;
	import ui.vbase.VButton;
	import ui.vbase.VCheckbox;
	import ui.vbase.VComponent;
	import ui.vbase.VEvent;
	import ui.vbase.VFill;
	import ui.vbase.VInputText;
	import ui.vbase.VOComponentItem;
	import ui.vbase.VRenderer;
	import ui.vbase.VSkin;
	import ui.vbase.VText;

	public class ComponentRenderer extends VRenderer {
		public static var digitBtValue:uint = 1;
		public var item:VOComponentItem;
		private const
			bg:VFill = new VFill(0xDFE0D5),
			text:VText = new VText(null, VText.MIDDLE, 0x591100, 10),
			box:VBox = new VBox(null, 2)
			;
		private var
			isBg1:Boolean,
			inputText:VInputText,
			checkbox:VCheckbox,
			okBt:VButton,
			infoText:VText,
			incBt:VButton,
			decBt:VButton,
			isDigitCache:Boolean
			;
		
		public function ComponentRenderer() {
			setSize(100, 18);
			addStretch(bg);
			add(text, { left:4, w:56, hP:100 });
			text.format.fontFamily = 'Myriad Pro';
			add(box, { left:62, right:2, hP:100 });
		}
		
		public function setSelection():void {
			if (inputText) {
				inputText.setSelection();
			}
		}
		
		override public function setData(data:Object):void {
			if (isBg1 != ((dataIndex & 1) == 0)) {
				isBg1 = !isBg1;
				bg.setFill(isBg1 ? 0xFCFDB3 : 0xDFE0D5);
			}
			
			item = data as VOComponentItem;

			var isSpec:Boolean = text.format.color != 0x591100;

			if (((item.mode & VOComponentItem.SPEC) != 0) != isSpec) {
				var format:TextLayoutFormat = text.format;
				if (isSpec) {
					format.fontSize = 10;
					format.color = 0x591100;
				} else {
					format.fontSize = 11;
					format.color = 0x006600;
				}
				text.syncFormat(false);
			}
			text.value = item.key;

			box.removeAll(false);
			const list:Vector.<VComponent> = box.list;

			//инфо текст
			if (Boolean(infoText) != ((item.mode & VOComponentItem.INFO) != 0)) {
				if (infoText) {
					infoText.dispose();
					infoText = null;
				} else {
					infoText = new VText(null, VText.CONTAIN, 0x591100, 10);
					infoText.format.fontFamily = 'Myriad Pro';
				}
			}
			if (infoText) {
				infoText.value = '<![CDATA[' + item.value + ']]>';
				list.push(infoText);
			}

			var isDigit:Boolean = (item.mode & VOComponentItem.DIGIT) != 0;
			if (Boolean(incBt) != isDigit) {
				if (incBt) {
					incBt.dispose();
					decBt.dispose();
					incBt = null;
					decBt = null;
				} else {
					incBt = VToolPanel.createEmbedButton('VToolScrollButton', VSkin.DRAW_FILL | VSkin.ROTATE_90);
					decBt = VToolPanel.createEmbedButton('VToolScrollButton', VSkin.DRAW_FILL | VSkin.ROTATE_270);
					incBt.layoutH = decBt.layoutH = 13;
					incBt.addClickListener(onBtChange, 1);
					decBt.addClickListener(onBtChange, -1);
				}
			}
			if (incBt) {
				list.push(decBt, incBt);
			}

			if (Boolean(inputText) != (isDigit || (item.mode & VOComponentItem.TEXT) != 0)) {
				if (inputText) {
					inputText.dispose();
					inputText = null;
					isDigitCache = false;
				} else {
					inputText = VToolPanel.createInputText();
					inputText.stretch();
					inputText.addListener(VEvent.CHANGE, onChange);
				}
			}
			if (inputText) {
				if (isDigitCache != isDigit) {
					isDigitCache = isDigit;
					inputText.restrict = isDigit ? new RegExp('^-?\\d*$') : null;
					if (isDigit) {
						inputText.addListener(KeyboardEvent.KEY_DOWN, onKeyDown);
					} else {
						inputText.removeListener(KeyboardEvent.KEY_DOWN, onKeyDown);
					}
				}
				//inputText.maxChars = isDigit ? 4 : 0;
				inputText.value = String(item.value);
				list.push(inputText);
			}

			if (Boolean(checkbox) != ((item.mode & VOComponentItem.CHECKBOX) != 0)) {
				if (checkbox) {
					checkbox.dispose();
					checkbox = null;
				} else {
					checkbox = VToolPanel.createCheckbox(null, item.checkbox);
					checkbox.addListener(VEvent.CHANGE, onChange);
				}
			}
			if (checkbox) {
				checkbox.checked = item.checkbox;
				list.push(checkbox);
			}

			//кнопка ok
			if (Boolean(okBt) != ((item.mode & VOComponentItem.BUTTON) != 0)) {
				if (okBt) {
					okBt.dispose();
					okBt = null;
				} else {
					okBt = VToolPanel.createTextButton('ok');
					okBt.addClickListener(onClickHandler);
					okBt.assignLayout({ hP:100, w:36 });
				}
			}
			if (okBt) {
				list.push(okBt);
			}
			box.addAll();
		}

		private function onClickHandler(event:MouseEvent):void {
			onChange(null);
		}
		
		private function onChange(event:VEvent):void {
			if (checkbox) {
				item.checkbox = checkbox.checked;
			}
			if (inputText) {
				item.value = inputText.value;
			}
			dispatcher.dispatchEvent(new VEvent(VEvent.SELECT, item));
		}
		
		private function onKeyDown(event:KeyboardEvent):void {
			if (event.keyCode == 33 || event.keyCode == 34) { //page up,  page down
				var n:Number = Number(inputText.value);
				if (!isNaN(n)) {
					if (event.keyCode == 33) {
						n += digitBtValue;
					} else {
						n -= digitBtValue;
					}
					
					inputText.value = n.toString();
					inputText.setSelection();
					
					onChange(null);
				}
			}
		}
		
		/**
		 * Обработчик изменения числовых значений с помощью кнопок btInc, btDec
		 * 
		 * @param	event		Объект события MouseEvent.CLICK
		 */
		private function onBtChange(event:MouseEvent):void {
			var n:Number = Number(inputText.value);
			if (!isNaN(n)) {
				n += digitBtValue * int((event.currentTarget as VButton).data);
				
				inputText.value = n.toString();
				inputText.setSelection();
				
				onChange(null);
			}
		}
		
	} //end class
}