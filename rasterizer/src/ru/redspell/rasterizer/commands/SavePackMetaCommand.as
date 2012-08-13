package ru.redspell.rasterizer.commands {
	import com.maccherone.json.JSON;

    import flash.filesystem.File;

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
            var metaFile:File = Facade.projDir.resolvePath(_pack.name).resolvePath(Config.META_FILENAME);

			if (meta.hasOwnProperty(_pack.name) && !Utils.objIsEmpty(meta[_pack.name])) {
				var fs:FileStream = new FileStream();
				fs.open(metaFile, FileMode.WRITE);
				fs.writeUTFBytes(com.maccherone.json.JSON.encode(meta[_pack.name]));
				fs.close();
			} else if (metaFile.exists) {
                metaFile.deleteFile();
            }
		}
	}
}