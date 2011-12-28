package ru.redspell.rasterizer.commands {
	import flash.events.Event;
	import flash.events.FileListEvent;
	import flash.filesystem.File;
	import flash.net.FileFilter;
	import flash.utils.setTimeout;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class AddSwfsCommand extends AbstractCommand {
		protected var _totalSwfs:uint = 0;
		protected var _loadedSwfs:uint = 0;

		protected function swf_completeHandler(event:Event):void {
			if (++_loadedSwfs == _totalSwfs) {
				Facade.app.setStatus('swfs loaded', true);
			} else {
				Facade.app.setStatus('loading swfs (' + _loadedSwfs + '/' + _totalSwfs + ')', true);
			}
		}

		protected function loadSwfs(event:FileListEvent):void {
			for each (var swfFile:File in event.files) {
				var dst:File = Facade.projSwfsDir.resolvePath(swfFile.name);
				var swf:Swf = Facade.projFactory.getSwf(dst.nativePath);

				swfFile.copyTo(dst, true);
				swf.addEventListener(Event.COMPLETE, swf_completeHandler);
				swf.loadClasses();

				(Facade.app.packsList.selectedItem as SwfsPack).addSwf(swf);

				_totalSwfs++;
			}
		}

		protected function swfs_selectMultipleHandler(event:FileListEvent):void {
			Facade.app.setStatus('loading swfs...', false, true);
			setTimeout(loadSwfs, Config.STATUS_REFRESH_TIME, event);
		}

		override public function unsafeExecute():void {
			var swfs:File = new File();

			swfs.addEventListener(FileListEvent.SELECT_MULTIPLE, swfs_selectMultipleHandler);
			swfs.browseForOpenMultiple('Select swfs', [new FileFilter('Swfs', '*.swf')]);
		}
	}
}