package {
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.geom.Rectangle;

	import ui.vbase.VFill;
	import ui.vbase.VRenderer;
	import ui.vbase.VSkin;
	import ui.vbase.VText;

	public class SkinItemRenderer extends VRenderer {
		public var container:Sprite = new Sprite();
		private const text:VText = new TextB(null, VText.SELECTION | VText.CONTAIN_CENTER);
		private var content:DisplayObject;

		public function SkinItemRenderer() {
			setSize(170, 170);
			addStretch(new VFill(0, 0));
			add(text, { left:-5, right:-4 });
			container.mouseChildren = container.mouseEnabled = false;
			addChild(container).y = 30;
		}

		override public function setData(data:Object):void {
			var item:VOSkin = data as VOSkin;
			var i:int = item.kind.indexOf('::');
			if (i >= 0) {
				i += 2;
			} else {
				i = 0;
			}
			text.value = item.kind.slice(i) + '\n' + item.loaderInfo.loader.name.slice(0, -4);
			if (content) {
				container.removeChild(content);
			}
			var skinClass:Class = item.loaderInfo.applicationDomain.getDefinition(item.kind) as Class;
			var obj:Object = new skinClass();
			if (obj is BitmapData) {
				obj = new Bitmap(obj as BitmapData);
			}
			content = obj as DisplayObject;
			if (content) {
				container.addChild(content);
				if (content is Sprite) {
					VSkin.controlMovieClipPlay(content as Sprite, false);
				}
				VSkin.contain(content, 170, 150, true);

				var rect:Rectangle = content.getRect(null);
				content.x = -rect.x * content.scaleX;
				content.y = -rect.y * content.scaleY;
			}
		}

	} //end class
}