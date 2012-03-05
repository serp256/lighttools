package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;
	import ru.redspell.rasterizer.utils.Utils;

	public class RefreshPackMetaCommand extends RefreshMetaCommand {
		protected var _pack:SwfsPack;

		public function RefreshPackMetaCommand(pack:SwfsPack) {
			_pack = pack;
		}

		override public function unsafeExecute():void {
			var meta:Object = Facade.proj.meta;

			if (!meta.hasOwnProperty(_pack.name)) {
				meta[_pack.name] = {};
			}

			var packMeta:Object = meta[_pack.name];

			if (_pack.checked) {
				delete packMeta.checked;
				if (Utils.objIsEmpty(packMeta)) {
					delete meta[_pack.name];
				}
			} else {
				packMeta.checked = false;
			}

			super.unsafeExecute();
		}
	}
}