package ru.redspell.rasterizer.commands {
	import mx.core.FlexGlobals;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Profile;
	import ru.redspell.rasterizer.views.MainMenu;

	public class InitCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			Facade.app = FlexGlobals.topLevelApplication as Rasterizer;
			Facade.app.mainMenu.setProfilesDp(Facade.profiles);
			Facade.runCommand(Facade.commandsFactory.getChooseProfileCommand(Facade.profiles.getItemAt(0) as Profile));
		}
	}
}