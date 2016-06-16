package {
	import flash.events.MouseEvent;

	import ui.vbase.SkinManager;
	import ui.vbase.VRenderer;
	import ui.vbase.VSkin;
	import ui.vbase.VText;

	public class PathItemRenderer extends VRenderer {
		private const text:VText = new VText(null, VText.CONTAIN);
		private var data:Object;

		public function PathItemRenderer() {
			setSize(200, 30);
			addStretch(SkinManager.getEmbed('HintBg', VSkin.STRETCH));
			add(text, { left:10, right:10, vCenter:1 });
			mouseChildren = false;
			buttonMode = true;
			addListener(MouseEvent.CLICK, onClick);
		}

		override public function setData(data:Object):void {
			text.value = String(data);
			this.data = data;
		}

		private function onClick(event:MouseEvent):void {
			dispatchVarianceEvent(0, data);
		}

	} //end class
}