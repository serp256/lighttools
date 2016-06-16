package ui.vbase {
	
	public class VOGridFilterItem {
		public var
			isFilterHide:Boolean,
			isHide:Boolean
			;

		public function get isUse():Boolean {
			return !(isFilterHide || isHide);
		}

	} //end class
}