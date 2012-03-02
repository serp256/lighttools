package ru.redspell.rasterizer.commands {
	import flash.filesystem.File;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;

	public class RemoveSwfCommand extends AbstractCommand {
		protected var _swf:Swf;

		public function RemoveSwfCommand(swf:Swf) {
			_swf = swf;
		}

		override public function unsafeExecute():void {
			var swfFile:File = new File (_swf.path);

			if (swfFile.exists) {
				swfFile.deleteFile();
			}

			var packOut:File = Facade.projOutDir.resolvePath(_swf.pack.name);

			for each (var cls:SwfClass in _swf.classes) {
				var out:File = packOut.resolvePath(cls.name.replace('::', '.'));

				if (out.exists) {
					out.deleteDirectory(true);
				}
			}

			_swf.pack.removeSwf(_swf);
		}
	}
}