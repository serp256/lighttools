package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;
	import ru.redspell.rasterizer.utils.Utils;

	public class SavePackMetaCommand extends AbstractCommand {
		protected var _pack:SwfsPack;

		public function SavePackMetaCommand(pack:SwfsPack) {
			_pack = pack;
		}

		override public function unsafeExecute():void {
			var meta:Object = Facade.proj.meta;

			if (meta.hasOwnProperty(_pack.name) && !Utils.objIsEmpty(meta[_pack.name])) {
				var fs:FileStream = new FileStream();
				fs.open(Facade.projDir.resolvePath(_pack.name).resolvePath(Config.META_FILENAME), FileMode.WRITE);
				fs.writeUTFBytes(JSON.encode(meta[_pack.name]));
				fs.close();
			}
		}
	}
}