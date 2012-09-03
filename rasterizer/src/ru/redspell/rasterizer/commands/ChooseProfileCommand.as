package ru.redspell.rasterizer.commands {
    import mx.collections.ArrayCollection;

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

			app.setProfileLbl(_profile.label);

            var packs:ArrayCollection = app.packsList.dataProvider as ArrayCollection;
            var swfs:ArrayCollection = app.swfsList.dataProvider as ArrayCollection;
            var classes:ArrayCollection = app.classesGrid.dataProvider as ArrayCollection;

            if (packs != null) {
                packs.refresh();
            }

            if (swfs != null) {
                swfs.refresh();
            }

            if (classes != null) {
                classes.refresh();
            }
		}
	}
}
