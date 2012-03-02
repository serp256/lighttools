package ru.redspell.rasterizer.views.events {
	import flash.events.Event;

	public class CheckboxColumnRendererEvent extends Event {
		public static const CHANGED:String = "changed";

		public var item:*;

		public function CheckboxColumnRendererEvent(type:String, item:*) {
			super(type, true, true);
			this.item = item;
		}
	}
}