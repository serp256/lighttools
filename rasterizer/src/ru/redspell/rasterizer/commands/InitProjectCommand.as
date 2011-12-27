package ru.redspell.rasterizer.commands {
	import flash.filesystem.File;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.Project;

	public class InitProjectCommand extends AbstractCommand {
		protected function initProject(proj:Project, projDir:File, swfsDir:File, outDir:File):void {
			Facade.projDir = projDir;
			Facade.projSwfsDir = swfsDir;
			Facade.projOutDir = outDir;
			Facade.proj = proj;
			Facade.app.packsList.dataProvider = proj;
		}
	}
}