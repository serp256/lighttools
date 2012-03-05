package ru.redspell.rasterizer.commands {
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.utils.Utils;

	public class RefreshSwfMetaCommand extends RefreshMetaCommand {
		protected var _swf:Swf;

		public function RefreshSwfMetaCommand(swf:Swf) {
			_swf = swf;
		}

		override public function unsafeExecute():void {
			var meta:Object = Facade.proj.meta;
			var pack:String = _swf.pack.name;
			var swf:String = _swf.filename;

			if (!meta.hasOwnProperty(pack)) {
				meta[pack] = {};
			}

			var packMeta:Object = meta[pack];

			if (!packMeta.hasOwnProperty(swf)) {
				packMeta[swf] = {};
			}

			var swfMeta:Object = packMeta[swf];

			if (_swf.animated) {
				delete swfMeta.animated;

				if (Utils.objIsEmpty(swfMeta)) {
					delete packMeta[swf];
				}

				if (Utils.objIsEmpty(packMeta)) {
					delete meta[pack];
				}
			} else {
				swfMeta.animated = false;
			}

			super.unsafeExecute();
		}
	}
}