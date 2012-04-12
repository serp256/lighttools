package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Profile;
	import ru.redspell.rasterizer.models.Swf;

	public class ChooseProfileCommand extends AbstractCommand {
		protected var _profile:Profile;

		public function ChooseProfileCommand(profile:Profile) {
			_profile = profile;
		}

		override public function unsafeExecute():void {
			Facade.profile = _profile;

			var app:Rasterizer = Facade.app;
			var dp:Swf = app.classesGrid.dataProvider as Swf;

			app.setProfileLbl(_profile.label);

			if (dp != null) {
				dp.refresh();
			}
		}
	}
}
