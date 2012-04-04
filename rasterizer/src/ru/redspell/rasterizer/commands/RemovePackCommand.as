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

			var packSrc:File = Facade.projDir.resolvePath(_pack.name);
			var packOut:File = Facade.projOutDir.resolvePath(_pack.name);

			if (packSrc.exists) {
				packSrc.deleteDirectory(true);
			}

			if (packOut.exists) {
				packOut.deleteDirectory(true);
			}
		}
	}
}