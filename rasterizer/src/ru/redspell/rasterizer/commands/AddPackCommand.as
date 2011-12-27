package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.utils.Config;

	public class AddPackCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			Facade.proj.addPack(Facade.projFactory.getSwfPack(Config.DEFAULT_PACK_NAME));
		}
	}
}