package ru.redspell.rasterizer.commands {
	import flash.filesystem.File;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.utils.Config;
	import ru.redspell.rasterizer.utils.Utils;

	public class AddPackCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			var name:String = Config.DEFAULT_PACK_NAME;
			var packDir:File = Facade.projDir.resolvePath(name);

			if (packDir.exists) {
				if (!packDir.isDirectory) {
					packDir.deleteFile();
				} else {
					var names:Array = []

					for each (var file:File in Facade.projDir.getDirectoryListing()) {
						if (file.isDirectory) {
							names.push(file.name)
						}
					}

					name = Utils.getFreeName(name, names);
				}
			}

			Facade.proj.addPack(Facade.projFactory.getSwfPack(name));
			packDir = Facade.projDir.resolvePath(name);
			packDir.createDirectory();
		}
	}
}