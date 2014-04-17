package ui.vbase {

	public class VAbstractItemRenderer extends VBaseComponent {
		public var dataIndex:uint;
		
		public function VAbstractItemRenderer(defaultW:uint = 50, defaultH:uint = 50):void {
			layout.w = defaultW;
			layout.h = defaultH;
		}
		
		public function setData(data:Object):void {
		}
		
	} //end class
}