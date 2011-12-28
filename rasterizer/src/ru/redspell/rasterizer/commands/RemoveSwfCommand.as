package ru.redspell.rasterizer.commands {
	import flash.filesystem.File;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Swf;

	public class RemoveSwfCommand extends AbstractCommand {
		protected var _swf:Swf;

		public function RemoveSwfCommand(swf:Swf) {
			_swf = swf;
		}

		override public function unsafeExecute():void {
			var swfFile:File = Facade.projSwfsDir.resolvePath(_swf.path);

			if (swfFile.exists) {
				swfFile.deleteFile();
			}

			_swf.pack.removeSwf(_swf);
		}
	}
}