package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.utils.Utils;

	public class RefreshClassMetaCommand extends SavePackMetaRunnerCommand {
		protected var _cls:SwfClass;

		public function RefreshClassMetaCommand(cls:SwfClass, save:Boolean = true) {
			super(cls.swf.pack, save);
			_cls = cls;
		}

		override public function unsafeExecute():void {
			var meta:Object = Facade.proj.meta;
			var pack:String = _cls.swf.pack.name;
			var swf:String = _cls.swf.filename;
			var cls:String = _cls.name;

			if (!meta.hasOwnProperty(pack)) {
				meta[pack] = {};
			}

			var packMeta:Object = meta[pack];

			if (!packMeta.hasOwnProperty(swf)) {
				packMeta[swf] = {};
			}

			var swfMeta:Object = packMeta[swf];

			if (!swfMeta.hasOwnProperty(cls)) {
				swfMeta[cls] = {};
			}

			var clsMeta:Object = swfMeta[cls];

			if (Utils.objIsEmpty(_cls.scales)) {
				delete clsMeta.scales;
			} else {
				clsMeta.scales = _cls.scales;
			}

			if (_cls.checked) {
				delete clsMeta.checked;
			} else {
				clsMeta.checked = false;
			}

			if (_cls.animated) {
				delete clsMeta.animated;
			} else {
				clsMeta.animated = false;
			}

			if (Utils.objIsEmpty(clsMeta)) {
				delete swfMeta[cls];
			}

			if (Utils.objIsEmpty(swfMeta)) {
				delete packMeta[swf];
			}

			if (Utils.objIsEmpty(packMeta)) {
				delete meta[pack];
			}

			super.unsafeExecute();
		}
	}
}