package ui.vbase {
	import flash.display.Sprite;
	import flash.display.StageDisplayState;
	import flash.events.FocusEvent;
	import flash.events.MouseEvent;

	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.container.ScrollPolicy;
	import flashx.textLayout.edit.EditManager;
	import flashx.textLayout.edit.ISelectionManager;
	import flashx.textLayout.edit.SelectionState;
	import flashx.textLayout.edit.TextScrap;
	import flashx.textLayout.elements.Configuration;
	import flashx.textLayout.elements.FlowLeafElement;
	import flashx.textLayout.elements.ParagraphElement;
	import flashx.textLayout.elements.SpanElement;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.events.FlowOperationEvent;
	import flashx.textLayout.formats.LineBreak;
	import flashx.textLayout.operations.DeleteTextOperation;
	import flashx.textLayout.operations.InsertTextOperation;
	import flashx.textLayout.operations.PasteOperation;
	import flashx.textLayout.operations.SplitParagraphOperation;

	public class VInputText extends VText {
		public static const
			MULTI_LINE:uint = 2048,
			BREAK_LINE:uint = 4096,
			DIGIT_RESTRICT:uint = 8192
			;
		private static const
			SCROLL_LINE:uint = MULTI_LINE | BREAK_LINE,
			ENTER_EVENT:uint = 16384
			;
		public var
			restrict:RegExp,
			maxChars:uint
			;
		private var
			bgSkin:VSkin,
			promptSpan:SpanElement
			;
		private const container:Sprite = new Sprite();

		public function VInputText(mode:uint = 0, bgSkin:VSkin = null, paddingH:int = 0, paddingV:int = 0) {
			super(null, mode);
			CONFIG::debug {
				useToolSolid();
			}
			if ((mode & DIGIT_RESTRICT) != 0) {
				restrict = new RegExp('^\\d+$');
			}
			if (bgSkin) {
				this.bgSkin = bgSkin;
				addChild(bgSkin);
				bgSkin.left = bgSkin.right = paddingH;
				bgSkin.top = bgSkin.bottom = paddingV;
				container.x = paddingH;
				container.y = paddingV;
			}
			addChild(container);

			textFlow.interactionManager = new EditManager();
			textFlow.addEventListener(FlowOperationEvent.FLOW_OPERATION_BEGIN, onFlowOperationBegin);
			textFlow.addEventListener(FlowOperationEvent.FLOW_OPERATION_END, onFlowOperationEnd);
			textFlow.addEventListener(FlowOperationEvent.FLOW_OPERATION_COMPLETE, onFlowOperationComplete);

			addListener(MouseEvent.MOUSE_DOWN, onMouseDown); //если в полном экране, то механизм выхода из него
		}

		override protected function updateMode():void {
			textFlow.lineBreak = (mode & SCROLL_LINE) != 0 ? LineBreak.TO_FIT : LineBreak.EXPLICIT;
			(textFlow.configuration as Configuration).manageEnterKey = (mode & MULTI_LINE) != 0;
		}

		public function useEnterEvent():void {
			(textFlow.configuration as Configuration).manageEnterKey = true;
			mode |= ENTER_EVENT;
		}

		private function onMouseDown(event:MouseEvent):void {
			if (stage.displayState == StageDisplayState.FULL_SCREEN) {
				stage.displayState = StageDisplayState.NORMAL;
			}
			if (promptSpan && promptSpan.parent) {
				value = null;
			}
		}
		
		public function set enabled(value:Boolean):void {
			mouseChildren = value;
		}

		override public function set value(str:String):void {
			while (textFlow.numChildren) {
				textFlow.removeChildAt(0);
			}
			if (str) {
				if ((mode & MULTI_LINE) == 0) {
					str = str.replace(new RegExp('\\n', 'g'), '');
				}
				if (promptSpan) {
					setPromptVisible(false);
				}
				createNewSpan(str);
			} else if (promptSpan) {
				setPromptVisible(!textFlow.interactionManager.focused);
			}
			syncContentSize(true);
		}

		private function createNewSpan(str:String):void {
			var span:SpanElement = new SpanElement();
			span.text = str;
			addNewSpan(span);
		}

		private function addNewSpan(span:SpanElement):void {
			var p:ParagraphElement = new ParagraphElement();
			p.addChild(span);
			textFlow.addChild(p);
		}

		override public function get value():String {
			return !(promptSpan && promptSpan.parent) ? textFlow.getText() : '';
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
		
		public function setPromptData(text:String, color:int = -1):void {
			if (text) {
				if (!promptSpan) {
					promptSpan = new SpanElement();
					addListener(FocusEvent.FOCUS_OUT, onFocusOut);
				}
				if (color >= 0) {
					promptSpan.color = color;
				}
				promptSpan.text = text;
				if (!textFlow.interactionManager.focused && textFlow.getText().length == 0) {
					value = null;
				}
			} else if (promptSpan) {
				removeListener(FocusEvent.FOCUS_OUT, onFocusOut);
				if (promptSpan.parent) {
					promptSpan = null;
					value = null;
				} else {
					promptSpan = null;
				}
			}
		}

		private function setPromptVisible(flag:Boolean):void {
			if (flag) {
				if (!promptSpan.parent) {
					addNewSpan(promptSpan);
				}
			} else {
				if (promptSpan.parent) {
					promptSpan.parent.removeChild(promptSpan);
				}
			}
		}
		
		private function onFocusOut(event:FocusEvent):void {
			if (textFlow.getText().length == 0) {
				value = null;
			}
		}
		
		override public function dispose():void {
			textFlow.removeEventListener(FlowOperationEvent.FLOW_OPERATION_BEGIN, onFlowOperationBegin);
			textFlow.removeEventListener(FlowOperationEvent.FLOW_OPERATION_END, onFlowOperationEnd);
			textFlow.removeEventListener(FlowOperationEvent.FLOW_OPERATION_COMPLETE, onFlowOperationComplete);
			textFlow.flowComposer.removeAllControllers();
			super.dispose();
		}
		
		private function onFlowOperationBegin(event:FlowOperationEvent):void {
			if (event.operation is InsertTextOperation) {
				var insertOperation:InsertTextOperation = event.operation as InsertTextOperation;
				var textToInsert:String = insertOperation.text;
//				if (restrict && textToInsert.search(restrict) < 0) {
//					event.preventDefault();
//				} else
				if (maxChars > 0) {
					var length1:int = textFlow.getText().length;
					var delSelOp:SelectionState = insertOperation.deleteSelectionState;
					if (delSelOp) {
						length1 -= delSelOp.absoluteEnd - delSelOp.absoluteStart;
					}
					if (length1 == maxChars) {
						event.preventDefault();
					} else {
						var length2:int = textToInsert.length;
						if (length1 + length2 > maxChars) {
							insertOperation.text = textToInsert.substr(0, maxChars - length1);
						}
					}
				}
			} else if (event.operation is DeleteTextOperation) {
				if (textFlow.getText().length == 0) {
					event.preventDefault();
				}
			} else if ((mode & ENTER_EVENT) != 0 && event.operation is SplitParagraphOperation) {
				event.preventDefault();
				dispatchEvent(new VEvent(VEvent.SELECT));
			}
		}
		
		private function onFlowOperationEnd(event:FlowOperationEvent):void {
			if (event.operation is PasteOperation) {
				var pasteOperation:PasteOperation = event.operation as PasteOperation;
				var hasConstraints:Boolean = restrict || maxChars > 0;

				if (!hasConstraints && (mode & MULTI_LINE) != 0) {
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
				if ((mode & MULTI_LINE) == 0) {
					pastedText = pastedText.replace(new RegExp('\\n', 'g'), '');
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
				do {
					text += leaf.text;
					leaf = leaf.getNextLeaf(p);
				} while (leaf);
				leaf = p.getLastLeaf().getNextLeaf(null);
				if (leaf) {
					text += "\n";
				}
			}
			
			return text;
		}
		
		private function onFlowOperationComplete(event:FlowOperationEvent):void {
			dispatcher.dispatchEvent(new VEvent(VEvent.CHANGE));
		}

		override protected function buildText(w:Number, h:Number):void {
			if (bgSkin) {
				w -= bgSkin.hPadding;
				h -= bgSkin.vPadding;
			}
			if (textFlow.flowComposer.numControllers == 0) {
				var cc:ContainerController = new ContainerController(container, w, h);
				cc.verticalScrollPolicy = (mode & SCROLL_LINE) != 0 ? ScrollPolicy.ON : ScrollPolicy.OFF;
				textFlow.flowComposer.addController(cc);
			} else {
				cc = textFlow.flowComposer.getControllerAt(0);
				cc.setCompositionSize(w, h);
			}
			textFlow.flowComposer.updateAllControllers();
		}

		override protected function calcContentSize():void {
			super.calcContentSize();
			if (bgSkin) {
				contentW += bgSkin.hPadding;
				if (contentW > updateW) {
					updateW = contentW;
				}
				contentH += bgSkin.vPadding;
				if (contentH > updateH) {
					updateH = contentH;
				}
			}
		}

		override public function updatePhase(force:Boolean = false):void {
			super.updatePhase(force);
			if (bgSkin && (bgSkin.w != w || bgSkin.h != h)) {
				bgSkin.setGeometrySize(w, h, false);
			}
		}

	} //end class
}