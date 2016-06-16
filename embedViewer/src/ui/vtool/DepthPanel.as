package ui.vtool {
	import ui.vbase.GridControl;
	import ui.vbase.VButton;
	import ui.vbase.VComponent;
	import ui.vbase.VFill;
	import ui.vbase.VGrid;
	import ui.vbase.VScrollBar;

	public class DepthPanel extends VComponent {
		public const
			backBt:VButton = VToolPanel.createTextButton('Назад', null, 'Blue'),
			grid:VGrid = new VGrid(1, 8, CaptureRenderer, null, 0, 3, VGrid.H_STRETCH | VGrid.FLOAT_INDEX)
			;

		public function DepthPanel(dp:Array) {
			addStretch(new VFill(0xFFFFFF));
			grid.dispatcher = this;
			if (dp.length > grid.vCount) {
				var scroll:VScrollBar = VToolPanel.createScrollBar();
				add(scroll, { right:0, bottom:0, h:grid.measuredHeight });
				(new GridControl(grid)).assignScrollBar(scroll);
				grid.setDataProvider(dp);
			} else {
				grid.setDataProvider(dp);
			}
			add(grid, { left:0, right:scroll ? scroll.measuredWidth + 2 : 0, bottom:3 });
			add(backBt, { w:68, h:25 });
		}

	} //end class
}