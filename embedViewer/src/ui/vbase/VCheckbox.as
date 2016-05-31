package ui.vbase {
	import flash.events.MouseEvent;

	public class VCheckbox extends VComponent {
		public var data:*;
		private var
			label:VComponent,
			checkSkin:VComponent
		;
		protected var isCheck:Boolean;

		/**
		 * Checkbox
		 * Представляет собой обрамляющую оболочку компонентов
		 * Вся компоновка должна осуществлятся через оберточный метод стилизации с установкой нужных позиций
		 *
		 * @param	boxSkin			Скин бокса
		 * @param	checkSkin		Скин галки
		 * @param	label			Текстовый компонент (может быть null)
		 * @param	selected		Текущее сосотояние выбора
		 */
		public function VCheckbox(boxSkin:VComponent, checkSkin:VComponent, label:VComponent, selected:Boolean = false) {
			mouseChildren = false;
			buttonMode = true;

			addChild(boxSkin);

			this.checkSkin = checkSkin;
			this.checked = selected;

			if (label) {
				this.label = label;
				addChild(label);
			}

			addListener(MouseEvent.CLICK, onClick);
			CONFIG::debug {
				useToolSolid();
			}
		}

		public function set text(value:String):void {
			if (label is VText) {
				(label as VText).value = value;
			} else if (label is VLabel) {
				(label as VLabel).text = value;
			}
		}

		public function set checked(value:Boolean):void {
			if (isCheck != value) {
				isCheck = value;
				if (value) {
					addChild(checkSkin);
					checkSkin.geometryPhase();
				} else {
					removeChild(checkSkin);
				}
			}
		}

		public function get checked():Boolean {
			return isCheck;
		}

		private function onClick(event:MouseEvent):void {
			var old:Boolean = isCheck;
			checked = !isCheck;
			if (old != isCheck) {
				dispatcher.dispatchEvent(new VEvent(VEvent.CHANGE, isCheck));
			}
		}

		CONFIG::debug
		override public function getToolPropList(out:Array):void {
			out.push(new VOComponentItem('checked', VOComponentItem.CHECKBOX, isCheck));
			if (label is VText || label is VLabel) {
				out.push(new VOComponentItem('text', VOComponentItem.TEXT, label is VText ? (label as VText).value : (label as VLabel).text));
			}
		}

		CONFIG::debug
		override public function updateToolProp(item:VOComponentItem):void {
			if (item.key == 'checked') {
				checked = item.checkbox;
			} else if (item.key == 'text') {
				text = item.valueString;
			}
		}

	} //end class
}