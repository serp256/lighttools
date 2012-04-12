package ru.redspell.rasterizer.commands {
	import com.maccherone.json.JSON;

	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Profile;
	import ru.redspell.rasterizer.utils.Config;

	public class CreateProfileCommand extends AbstractCommand {
		protected var _label:String;
		protected var _scale:Number;

		public function CreateProfileCommand(label:String, scale:Number) {
			_label = label;
			_scale = scale;
		}

		override public function unsafeExecute():void {
			if (Facade.projDir != null) {
				var profile:Profile = Profile.create(_label != '' ? _label : 'new profile', _scale > 0 ? _scale : 1);
				Facade.profiles.addItem(profile);

				var s:FileStream = new FileStream();
				s.open(Facade.projDir.resolvePath(Config.PROFILES_FILENAME), FileMode.WRITE);
				s.writeUTFBytes(JSON.encode(Facade.profiles.source.slice(1)));
				s.close();
			}
		}
	}
}