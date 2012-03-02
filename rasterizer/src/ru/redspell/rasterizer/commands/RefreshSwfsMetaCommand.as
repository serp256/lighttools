package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class RefreshSwfsMetaCommand extends AbstractCommand {
		protected var _pack:SwfsPack;

		public function RefreshSwfsMetaCommand(pack:SwfsPack) {
			_pack = pack;
		}

		override public function unsafeExecute():void {
			var meta:Object = {};

			for each (var swf:Swf in _pack.swfs) {
				if (!swf.animated) {
					meta[swf.filename] = { animated:false };
				}
			}

			var fs:FileStream = new FileStream();

			fs.open(Facade.projDir.resolvePath(_pack.name).resolvePath(Config.META_FILENAME), FileMode.WRITE);
			fs.writeUTFBytes(JSON.encode(meta));
			fs.close();
		}
	}
}