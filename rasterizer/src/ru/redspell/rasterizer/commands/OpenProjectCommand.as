package ru.redspell.rasterizer.commands {
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.net.FileFilter;
	import flash.utils.setTimeout;

	import ru.nazarov.binstore.BinStore;
	import ru.nazarov.binstore.IBinStore;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class OpenProjectCommand extends InitProjectCommand {
		protected function openProject(event:Event):void {
			var projFile:File = event.target as File;

			var store:IBinStore = new BinStore();
			store.read(projFile, Config.ENDIAN);

			var projDir:File = projFile.parent;
			var swfsDir:File = projDir.resolvePath(Config.DEFAULT_SWFS_DIR);
			var outDir:File = projDir.resolvePath(Config.DEFAULT_OUT_DIR);

			initProject(Facade.serializersFactory.getProjectSerializer().deserialize(store.getChunkAt(0).bytes), projDir, swfsDir, outDir);

			for each (var pack:SwfsPack in Facade.proj) {
				for each (var swf:Swf in pack) {
					swf.loadClasses(Facade.projSwfsDir, false);
				}
			}

			Facade.app.setStatus('project opened', true);
		}

		protected function projFile_selectHandler(event:Event):void {
			Facade.app.setStatus('opening project...', false, true);
			setTimeout(openProject, Config.STATUS_REFRESH_TIME, event);
		}

		override public function unsafeExecute():void {
			var projFile:File = new File();

			projFile.addEventListener(Event.SELECT, projFile_selectHandler);
			projFile.browseForOpen('Select rasterizer project', [new FileFilter('rasterizer project', '*' + Config.PROJECT_FILE_EXT)]);
		}
	}
}