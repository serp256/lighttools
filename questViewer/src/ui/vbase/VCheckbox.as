package ui.vbase {
	import flash.events.MouseEvent;
	
	public class VCheckbox extends VBaseComponent {
		private var label:VLabel;
		private var boxSkin:VSkin;
		private var checkSkin:VSkin;
		private var flag:Boolean;
		
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
		public function VCheckbox(boxSkin:VSkin, checkSkin:VSkin, label:VLabel, selected:Boolean = false):void {
			mouseChildren = false;
			buttonMode = true;
			
			this.boxSkin = boxSkin;
			addChild(boxSkin);
			
			this.checkSkin = checkSkin;
			addChild(checkSkin);
			checkSkin.visible = flag = selected;
			
			if (label) {
				this.label = label;
				addChild(label);
			}
			
			addListener(MouseEvent.CLICK, onClickHandler);
		}
		
		public function set text(value:String):void {
			if (label) {
				label.text = value;
			}
		}
		
		public function set selected(value:Boolean):void {
			checkSkin.visible = flag = value;
		}
		
		public function get selected():Boolean {
			return flag;
		}
		
		private function onClickHandler(event:MouseEvent):void {
			selected = !flag;
			dispatcher.dispatchEvent(new VEvent(VEvent.CHANGE, flag));
		}
		
	} //end class
}