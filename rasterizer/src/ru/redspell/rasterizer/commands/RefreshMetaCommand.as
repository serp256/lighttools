package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.utils.Config;

	public class RefreshMetaCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			var fs:FileStream = new FileStream();
			fs.open(Facade.projDir.resolvePath(Config.META_FILENAME), FileMode.WRITE);
			fs.writeUTFBytes(JSON.encode(Facade.proj.meta));
			fs.close();
		}
	}
}