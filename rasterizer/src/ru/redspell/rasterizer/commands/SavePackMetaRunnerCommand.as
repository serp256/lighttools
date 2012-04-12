package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.models.SwfsPack;

	public class SavePackMetaRunnerCommand extends AbstractCommand {
		protected var _pack:SwfsPack;
		protected var _save:Boolean;

		public function SavePackMetaRunnerCommand(pack:SwfsPack, save:Boolean = true) {
			_pack = pack;
			_save = save;
		}

		override public function unsafeExecute():void {
			if (_save) {
				Facade.runCommand(Facade.commandsFactory.getSavePackMetaCommand(_pack));
			}
		}
	}
}