package ru.redspell.rasterizer.commands {
	import flash.events.Event;
	import flash.filesystem.File;

	import mx.collections.IList;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class NewProjectCommand extends InitProjectCommand {
		protected function projDir_selectHandler(event:Event):void {
			var projDir:File = event.target as File;

			if (projDir.exists && projDir.isDirectory) {
				projDir.deleteDirectory(true);
			}

			projDir.createDirectory();

			var swfsDir:File = projDir.resolvePath(Config.DEFAULT_SWFS_DIR);
			var outDir:File = projDir.resolvePath(Config.DEFAULT_OUT_DIR);
			var proj:Project = Facade.projFactory.getProject();

			swfsDir.createDirectory();
			outDir.createDirectory();

			initProject(proj, projDir, swfsDir, outDir);
			Facade.app.setLock(false);
		}

		override public function unsafeExecute():void {
			Facade.app.setLock(true);

			var projDir:File = new File();

			projDir.addEventListener(Event.SELECT, projDir_selectHandler);
			projDir.browseForSave('Select project directory');
		}
	}
}