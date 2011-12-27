package ru.redspell.rasterizer.commands {
	import flash.events.FileListEvent;
	import flash.filesystem.File;
	import flash.net.FileFilter;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfsPack;

	public class AddSwfsCommand extends AbstractCommand {
		protected function swfs_selectMultipleHandler(event:FileListEvent):void {
			for each (var swfFile:File in event.files) {
				var dst:File = Facade.projSwfsDir.resolvePath(swfFile.name);
				var swf:Swf = Facade.projFactory.getSwf(dst.nativePath);

				swfFile.copyTo(dst, true);
				swf.loadClasses();

				(Facade.app.packsList.selectedItem as SwfsPack).addSwf(swf);
			}
		}

		override public function unsafeExecute():void {
			var swfs:File = new File();

			swfs.addEventListener(FileListEvent.SELECT_MULTIPLE, swfs_selectMultipleHandler);
			swfs.browseForOpenMultiple('Select swfs', [new FileFilter('Swfs', '*.swf')]);
		}
	}
}