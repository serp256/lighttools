package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;

	public class SaveProjectMetaRunnerCommand extends AbstractCommand {
		protected var _save:Boolean;

		public function SaveProjectMetaRunnerCommand(save:Boolean = true) {
			_save = save;
		}

		override public function unsafeExecute():void {
			if (_save) {
				Facade.runCommand(Facade.commandsFactory.getSaveProjectMetaCommand());
			}
		}
	}
}