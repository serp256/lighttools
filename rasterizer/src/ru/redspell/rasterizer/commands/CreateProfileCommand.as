package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Profile;

	public class CreateProfileCommand extends AbstractCommand {
		protected var _label:String;
		protected var _scale:Number;

		public function CreateProfileCommand(label:String, scale:Number) {
			_label = label;
			_scale = scale;
		}

		override public function unsafeExecute():void {
			var profile:Profile = Profile.create(_label != '' ? _label : 'new profile', _scale > 0 ? _scale : 1);
			Facade.profiles.addItem(profile);
		}
	}
}