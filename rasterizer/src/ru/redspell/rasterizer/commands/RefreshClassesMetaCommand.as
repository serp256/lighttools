package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.File;

	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.utils.Config;

	public class RefreshClassesMetaCommand extends AbstractCommand {
		protected var _swf:Swf;

		public function RefreshClassesMetaCommand(swf:Swf) {
			_swf = swf;
		}

		override public function unsafeExecute():void {
			var meta:Object = {};

			for each (var cls:SwfClass in _swf.classes) {
				if (!cls.checked) {
					meta[cls.name] = { checked:false };

					var clsOut:File = Facade.projOutDir.resolvePath(_swf.pack.name).resolvePath(cls.name.replace('::', '.'));

					if (clsOut.exists) {
						clsOut.deleteDirectory(true);
					}
				}

				if (!cls.animated) {
					if (meta.hasOwnProperty(cls.name)) {
						meta[cls.name]['animated'] = false;
					} else {
						meta[cls.name] = { animated:false };
					}
				}
			}

			var fs:FileStream = new FileStream();

			fs.open(Facade.projDir.resolvePath(_swf.path + Config.META_EXT), FileMode.WRITE);
			fs.writeUTFBytes(JSON.encode(meta));
			fs.close();
		}
	}
}