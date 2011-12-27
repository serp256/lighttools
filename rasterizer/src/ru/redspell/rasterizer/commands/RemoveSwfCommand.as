package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Swf;

	public class RemoveSwfCommand extends AbstractCommand {
		protected var _swf:Swf;

		public function RemoveSwfCommand(swf:Swf) {
			_swf = swf;
		}

		override public function unsafeExecute():void {
			_swf.pack.removeSwf(_swf);
		}
	}
}