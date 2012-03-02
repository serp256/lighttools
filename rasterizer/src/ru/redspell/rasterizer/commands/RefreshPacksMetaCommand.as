package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class RefreshPacksMetaCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			var meta:Object = {};

			for each (var pack:SwfsPack in Facade.proj.packs) {
				if (!pack.checked) {
					meta[pack.name] = { checked:false };
				}
			}

			var fs:FileStream = new FileStream();

			fs.open(Facade.projDir.resolvePath(Config.META_FILENAME), FileMode.WRITE);
			fs.writeUTFBytes(JSON.encode(meta));
			fs.close();
		}
	}
}