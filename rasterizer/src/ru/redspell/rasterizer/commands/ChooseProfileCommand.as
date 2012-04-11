package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Profile;

	public class ChooseProfileCommand extends AbstractCommand {
		protected var _profile:Profile;

		public function ChooseProfileCommand(profile:Profile) {
			_profile = profile;
		}

		override public function unsafeExecute():void {
			Facade.profile = _profile;
			Facade.app.setProfileLbl(_profile.label);
		}
	}
}
