package ui.vbase {
	import flash.display.StageDisplayState;
	import flash.events.FocusEvent;
	import flash.events.MouseEvent;
	import flashx.textLayout.conversion.TextLayoutImporter;
	import flashx.textLayout.edit.EditManager;
	import flashx.textLayout.edit.ISelectionManager;
	import flashx.textLayout.edit.SelectionState;
	import flashx.textLayout.edit.TextScrap;
	import flashx.textLayout.elements.Configuration;
	import flashx.textLayout.elements.FlowLeafElement;
	import flashx.textLayout.elements.ParagraphElement;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.events.FlowOperationEvent;
	import flashx.textLayout.formats.LineBreak;
	import flashx.textLayout.formats.VerticalAlign;
	import flashx.textLayout.formats.WhiteSpaceCollapse;
	import flashx.textLayout.operations.InsertTextOperation;
	import flashx.textLayout.operations.PasteOperation;
	
	public class VInputText extends VLabel {
		public static const MULTILINE:uint = 2048;
		public static const LINEBREAK:uint = 4096;
		public var restrict:RegExp;
		public var maxChars:uint;
		private var bgSkin:VSkin;
		private var padding:uint;
		//параметры подсказки
		private var promptDown:Boolean; //показывет, что текстовое поле находится в режиме приглашения ввода
		private var promptStyle:String;
		private var promptMessage:String;
		//private static const importer:TextLayoutImporter = new TextLayoutImporter();
		
		public function VInputText(text:String = null, mode:uint = 0, maxChars:uint = 0, restrict:RegExp = null, paddingH:uint = 0, paddingV:uint = 0, bgSkin:VSkin = null):void {
			this.restrict = restrict;
			this.maxChars = maxChars;
			padding |= paddingH & 0xFF;
			padding |= (paddingV & 0xFF) << 8;
			
			super(text, mode);
			mouseChildren = true;
			
			if (bgSkin) {
				this.bgSkin = bgSkin;
				addChildAt(bgSkin, 0);
			}
			addListener(MouseEvent.MOUSE_DOWN, onMouseDownHandler); //если в полном экране, то механизм выхода из него
			addListener(FocusEvent.FOCUS_OUT, resetPrompt);
		}
		
		private function onMouseDownHandler(event:MouseEvent):void {
			if (stage.displayState == StageDisplayState.FULL_SCREEN) {
				stage.displayState = StageDisplayState.NORMAL;
			}
			if (promptDown) {
				promptDown = false;
				text = '<p ' + promptStyle + '/>';
				setSelection();
			}
		}
		
		public function set enabled(value:Boolean):void {
			mouseChildren = value;
		}
		
		override public function set text(value:String):void {
			disposeTextFlow();
			
			if (value) {
				try {
					textFlow = importer.createTextFlowFromXML(
						new XML('<TextFlow xmlns="http://ns.adobe.com/textLayout/2008" version="3.0.0">' + value + '</TextFlow>')
					);
					var config:Configuration = textFlow.configuration as Configuration;
					config.manageEnterKey = (mode & MULTILINE) != 0;
					if ((mode & LINEBREAK) == 0) {
						textFlow.lineBreak = LineBreak.EXPLICIT;
					}
					if (mode & VLabel.VERTICAL_MIDDLE) {
						textFlow.verticalAlign = VerticalAlign.MIDDLE;
					}
					if (padding > 0) {
						textFlow.paddingRight = textFlow.paddingLeft = padding & 0xFF;
						textFlow.paddingTop = textFlow.paddingBottom = (padding >> 8) & 0xFF;
					}
					
					textFlow.interactionManager = new EditManager();
					textFlow.addEventListener(FlowOperationEvent.FLOW_OPERATION_BEGIN, onFlowOperationBeginHandler);
					textFlow.addEventListener(FlowOperationEvent.FLOW_OPERATION_END, onFlowOperationEndHandler);
					textFlow.addEventListener(FlowOperationEvent.FLOW_OPERATION_COMPLETE, onFlowOperationCompleteHandler);
				} catch (error:Error) {
				}
			}
			
			syncContentSize(true);
		}
		
		override public function get text():String {
			return (textFlow && !promptDown) ? textFlow.getText() : '';
		}
		
		/**
		 * Задать выделение 
		 * 
		 * @param	begin		Стартовая позиция, если &lt; 0, то идет отчет от конца текста
		 * @param	end			Финишная позиция, если &lt; 0, то идет отчет от конца текста
		 */
		public function setSelection(begin:int = -1, end:int = -1):void {
			var sm:ISelectionManager = textFlow.interactionManager;
			sm.setFocus();
			var num:uint = textFlow.textLength;
			if (begin < 0) {
				begin += num;
			}
			if (begin < 0) {
				begin = 0;
			} else if (begin >= num) {
				begin = (num > 0) ? num - 1 : 0;
			}
			if (end < 0) {
				end += num;
			}
			if (end < begin) {
				end = begin;
			} else if (end >= num) {
				end = (num > 0) ? num - 1 : 0;
			}
			
			sm.selectRange(begin, end);
			sm.refreshSelection();
		}
		
		public function setPromptData(style:String, message:String):void {
			promptStyle = style;
			promptMessage = message;
			resetPrompt();
		}
		
		public function resetPrompt(event:FocusEvent = null):void {
			if (promptStyle && promptMessage && (!event || text.length == 0)) {
				promptDown = true;
				text = '<p ' + promptStyle + '>' + promptMessage + '</p>';
			}
		}
		
		override public function updatePhase(force:Boolean = false):void {
			super.updatePhase(force);
			if (bgSkin && visible) {
				if (bgSkin.w != w || bgSkin.h != h) {
					bgSkin.setGeometrySize(w, h, false);
				}
			}
		}
		
		private function disposeTextFlow():void {
			if (textFlow) {
				clearText();
				textFlow.removeEventListener(FlowOperationEvent.FLOW_OPERATION_BEGIN, onFlowOperationBeginHandler);
				textFlow.removeEventListener(FlowOperationEvent.FLOW_OPERATION_END, onFlowOperationEndHandler);
				textFlow.removeEventListener(FlowOperationEvent.FLOW_OPERATION_COMPLETE, onFlowOperationCompleteHandler);
				textFlow = null;
			}
		}
		
		override public function dispose():void {
			disposeTextFlow();
			super.dispose();
		}
		
		private function onFlowOperationBeginHandler(event:FlowOperationEvent):void {
			if (event.operation is InsertTextOperation) {
				var insertOperation:InsertTextOperation = event.operation as InsertTextOperation;
				var textToInsert:String = insertOperation.text;
				if (restrict != null) {
					if (textToInsert.search(restrict) == -1) {
						event.preventDefault();
						return;
					}
				}
				
				if (maxChars != 0) {
					var delSelOp:SelectionState = insertOperation.deleteSelectionState;
					var delLen:int = (delSelOp == null) ? 0 : delSelOp.absoluteEnd - delSelOp.absoluteStart;
					
					//TextConverter.getExporter(TextConverter.PLAIN_TEXT_FORMAT).export(ConversionType.STRING_TYPE
					var length1:int = textFlow.getText().length - delLen;
					var length2:int = textToInsert.length;
					if (length1 + length2 > maxChars) {
						insertOperation.text = textToInsert.substr(0, maxChars - length1);
					}
				}
			}
		}
		
		private function onFlowOperationEndHandler(event:FlowOperationEvent):void {
			if (event.operation is PasteOperation) {
				var pasteOperation:PasteOperation = event.operation as PasteOperation;
				var hasConstraints:Boolean = restrict || maxChars;
				
				if (!hasConstraints && (mode & MULTILINE) != 0) {
					return;
				}
				
				var textScrap:TextScrap = pasteOperation.textScrap;
				if (!textScrap) {
					return;
				}
				var pastedText:String = extractText(textScrap.textFlow);
				if (!hasConstraints && pastedText.indexOf("\n") == -1) {
					return;
				}
				
				var textLength:int = pastedText.length;
				if ((mode & MULTILINE) == 0) {
					pastedText = pastedText.replace(/\n/g, '');
				}
				
				var editManager:EditManager = textFlow.interactionManager as EditManager;
				
				var selectionState:SelectionState = new SelectionState(
					pasteOperation.textFlow, pasteOperation.absoluteStart, 
					pasteOperation.absoluteStart + textLength
				);
				editManager.deleteText(selectionState);
				selectionState = new SelectionState(pasteOperation.textFlow, pasteOperation.absoluteStart, pasteOperation.absoluteStart);
				editManager.insertText(pastedText, selectionState);
			}
		}
		
		private function extractText(textFlow:TextFlow):String {
			var text:String = '';
			
			var leaf:FlowLeafElement = textFlow.getFirstLeaf();
			while (leaf) {
				var p:ParagraphElement = leaf.getParagraph();
				for (;;) {
					text += leaf.text;
					leaf = leaf.getNextLeaf(p);
					if (!leaf) {
						break;
					}
				}
				leaf = p.getLastLeaf().getNextLeaf(null);
				if (leaf) {
					text += "\n";
				}
			}
			
			return text;
		}
		
		private function onFlowOperationCompleteHandler(event:FlowOperationEvent):void {
			dispatcher.dispatchEvent(new VEvent(VEvent.CHANGE));
		}
		
	} //end class
}