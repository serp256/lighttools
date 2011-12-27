package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;

	public class RemovePackCommand extends AbstractCommand {
		protected var _pack:SwfsPack;

		public function RemovePackCommand(pack:SwfsPack) {
			_pack = pack;
		}

		override public function unsafeExecute():void {
			Facade.proj.removePack(_pack);
		}
	}
}