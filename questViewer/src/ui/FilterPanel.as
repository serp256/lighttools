package ui {
	import ui.vbase.*;
	
	/**
	 * окошко для ввода имени друга
	 */
	public class FilterPanel extends VBaseComponent {
		public var inputText:VInputText = new VInputText(null, VLabel.VERTICAL_MIDDLE, 40);
		
		
		public function FilterPanel(message:String = null, fontSize:uint = 16, fw:uint = 210, fh:uint = 36):void {
			layout.w = fw;
			layout.h = fh;
			
			add(AssetManager.getEmbedSkin('FilterPanel', VSkin.STRETCH), { w:'100%', h:'100%' } );
			
			var icon:VSkin = AssetManager.getEmbedSkin('ToWishlistIcon', VSkin.CONTAIN | VSkin.LEFT);
			add(icon, { left:3, h:layout.h, w:layout.h } );

			inputText.dispatcher = this;
			if (message == null) {
				message = Lang.getString('input_name');
				if (message.length > 20) {
					fontSize = 14;
				}
			}
			inputText.setPromptData('fontSize="' + fontSize + '"' + Style.brownColor, message);
			add(inputText, {  h:layout.h, left: icon.measuredWidth+5, right:1 } );
		}
	}
	
}