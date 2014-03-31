package ui.vtool {
	import ui.GridConnector;
	import ui.vbase.*;
	
	public class DepthPanel extends VBaseComponent {
		public var btBack:VButton = VToolPanel.createTextButton('VToolBlueButtonBg', 'Назад');
		public var gridPanel:VGridPanel;
		private var gridConnector:GridConnector;
		
		public function DepthPanel(dp:Array):void {
			add(new VFill(0xFFFFFF), { w:'100%', h:'100%' } );
			gridPanel = new VGridPanel(1, 8, CaptureItemRenderer, null, 0, 3, VGridPanel.H_STREACH | VGridPanel.DRIFT_INDEX);
			gridPanel.dispatcher = this;
			if (dp.length > gridPanel.renders.length) {
				var scrollBar:VScrollBar = VToolPanel.createScrollBar();
				add(scrollBar, { right:0, top:0, bottom:30 } );
				gridConnector = GridConnector.createWithScroll(gridPanel, scrollBar);
				gridConnector.changeDp(dp);
			} else {
				gridPanel.setDataProvider(dp);
			}
			add(gridPanel, { left:0, right:scrollBar ? scrollBar.contentWidth + 2 : 0, top:0, bottom:30 } );
			add(btBack, { hCenter:0, bottom:0, w:68, h:25 } );
		}
		
	} //end class
}