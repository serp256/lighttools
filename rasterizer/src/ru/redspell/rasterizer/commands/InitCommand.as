package ru.redspell.rasterizer.commands {
	import mx.core.FlexGlobals;

	import ru.nazarov.asmvc.command.AbstractCommand;

	public class InitCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			Facade.app = FlexGlobals.topLevelApplication as Rasterizer;
		}
	}
}