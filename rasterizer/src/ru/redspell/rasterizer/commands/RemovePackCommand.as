package ru.redspell.rasterizer.commands {
	import flash.filesystem.File;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;

	public class RemovePackCommand extends AbstractCommand {
		protected var _pack:SwfsPack;

		public function RemovePackCommand(pack:SwfsPack) {
			_pack = pack;
		}

		override public function unsafeExecute():void {
			Facade.proj.removePack(_pack);

			var packSrc:File = Facade.projDir;
			var packOut:File = Facade.projOutDir;

			if (packSrc.exists) {
				packSrc.resolvePath(_pack.name).deleteDirectory(true);
			}

			if (packOut.exists) {
				packOut.resolvePath(_pack.name).deleteDirectory(true);
			}
		}
	}
}