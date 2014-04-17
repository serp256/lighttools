package ui.vtool {
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import ui.vbase.*;
	
	public class ComponentItemRenderer extends VAbstractItemRenderer {
		public static var digitBtValue:uint = 1;
		
		private var bg:VFill = new VFill(0);
		private var label:VLabel = new VLabel(null, VLabel.VERTICAL_MIDDLE);
		public var item:VOComponentItem;
		private var box:VBox;
		private var inputText:VInputText;
		private var checkbox:VCheckbox;
		
		public function ComponentItemRenderer():void {
			super(100, 18);
			add(bg, { w:'100%', h:'100%' } );
			add(label, { left:4, w:56, h:'100%' } );
		}
		
		public function setSelection():void {
			if (inputText) {
				inputText.setSelection();
			}
		}
		
		override public function setData(data:Object):void {
			bg.changeEnv(((dataIndex & 1) == 0) ? 0xFCFDB3 : 0xDFE0D5);
			
			if (box) {
				remove(box);
			}
			inputText = null;
			checkbox = null;
			var componentList:Vector.<VBaseComponent> = new Vector.<VBaseComponent>();
			
			item = data as VOComponentItem;
			label.text = '<p fontSize="10" color="0x591100">' + item.key + '</p>';
			
			if (item.mode & VOComponentItem.BUTTON) {
				var bt:VButton = VToolPanel.createTextButton('VToolGreenButtonBg', 'ok');
				bt.addClickListener(onClickHandler);
				bt.setLayout( { h:'100%', w:36 } );
				componentList.push(bt);
			} else if (item.mode & VOComponentItem.INFO) {
				componentList.push(new VLabel('<p fontSize="10" color="0x591100"><![CDATA[' + item.value + ']]></p>', VLabel.CONTAIN));
			} else {
				var isDigit:Boolean = (item.mode & VOComponentItem.DIGIT) != 0;
				if (isDigit || (item.mode & VOComponentItem.TEXT) != 0) {
					inputText = new VInputText(null,
						0, isDigit ? 4 : 0,  isDigit ? /^[-\d]+$/ : null, 6, 3, AssetManager.getEmbedSkin('VToolBgInputText', VSkin.STRETCH)
					);
					setInputText(String(item.value));
					inputText.setLayout( { w:'100%', h:'100%' } );
					inputText.addListener(VEvent.CHANGE, onChangeHandler);
					if (isDigit) {
						inputText.addListener(KeyboardEvent.KEY_DOWN, onKeyDownHandler);
						
						var btInc:VButton = VToolPanel.createEmbedButton('VToolScrollButton', VSkin.ROTATE_90);
						btInc.setLayout( { h:13 } );
						var btDec:VButton = VToolPanel.createEmbedButton('VToolScrollButton', VSkin.ROTATE_270);
						btDec.setLayout( { h:13 } );
						btInc.addClickListener(onBtChangeHandler, 1);
						btDec.addClickListener(onBtChangeHandler, -1);
						
						componentList.push(btDec, btInc);
					}
					componentList.push(inputText);
				}
				if (item.mode & VOComponentItem.CHECKBOX) {
					checkbox = VToolPanel.createCheckbox(null, item.checkbox);
					checkbox.addListener(VEvent.CHANGE, onChangeHandler);
					componentList.push(checkbox);
				}
			}
			
			box = new VBox(componentList, false, 2);
			add(box, { left:62, right:2, h:'100%' } );
		}
		
		private function onClickHandler(event:MouseEvent):void {
			onChangeHandler(null);
		}
		
		private function onChangeHandler(event:VEvent):void {
			if (checkbox) {
				item.checkbox = checkbox.selected;
			}
			if (inputText) {
				item.value = inputText.text;
			}
			dispatcher.dispatchEvent(new VEvent(VEvent.SELECT, item));
		}
		
		private function onKeyDownHandler(event:KeyboardEvent):void {
			if (event.keyCode == 33 || event.keyCode == 34) { //page up,  page down
				var n:Number = Number(inputText.text);
				if (!isNaN(n)) {
					if (event.keyCode == 33) {
						n += digitBtValue;
					} else {
						n -= digitBtValue;
					}
					
					inputText.text = '<p color="0xFF0000" fontSize="12">' + n + '</p>';
					inputText.setSelection();
					
					onChangeHandler(null);
				}
			}
		}
		
		/**
		 * Обработчик изменения числовых значений с помощью кнопок btInc, btDec
		 * 
		 * @param	event		Объект события MouseEvent.CLICK
		 */
		private function onBtChangeHandler(event:MouseEvent):void {
			var n:Number = Number(inputText.text);
			if (!isNaN(n)) {
				n += digitBtValue * int((event.currentTarget as VButton).data);
				
				inputText.text = '<p color="0xFF0000" fontSize="12">' + n + '</p>';
				inputText.setSelection();
				
				onChangeHandler(null);
			}
		}
		
		public function setInputText(value:String):void {
			if (inputText) {
				inputText.text = '<p color="0xFF0000" fontSize="12"><![CDATA[' + value + ']]></p>';
			}
		}
		
	} //end class
}