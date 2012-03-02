package ru.redspell.rasterizer.factories {
	import ru.redspell.rasterizer.commands.*;
	import ru.nazarov.asmvc.command.ICommand;
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class CommandsFactory {
		public function getNewProjectCommand():ICommand {
			return new NewProjectCommand();
		}

		public function getOpenProjectCommand():ICommand {
			return new OpenProjectCommand();
		}

		public function getSaveProjectCommand(beforeStatus:String = null, afterStatus:String = null):ICommand {
			return new SaveProjectCommand(beforeStatus ? beforeStatus : Config.DEFAULT_BEFORE_SAVE_STATUS,
				afterStatus ? afterStatus : Config.DEFAULT_AFTER_SAVE_STATUS);
		}

		public function getInitCommand():ICommand {
			return new InitCommand();
		}

		public function getAddPackCommand():ICommand {
			return new AddPackCommand();
		}

		public function getRemovePackCommand(pack:SwfsPack):ICommand {
			return new RemovePackCommand(pack);
		}

		public function getAddSwfsCommand():ICommand {
			return new AddSwfsCommand();
		}

		public function getRemoveSwfCommand(swf:Swf):ICommand {
			return new RemoveSwfCommand(swf);
		}

		public function getExportCommand(proj:Project):ICommand {
			return new ExportCommand(proj);
		}

		public function getRenamePackCommand(pack:SwfsPack, prevName:String):ICommand {
			return new RenamePackCommand(pack, prevName);
		}

		public function getRefreshPacksMetaCommand():ICommand {
			return new RefreshPacksMetaCommand();
		}

		public function getRefreshSwfsMetaCommand(pack:SwfsPack):ICommand {
			return new RefreshSwfsMetaCommand(pack);
		}

		public function getRefreshClassesMetaCommand(swf:Swf):ICommand {
			return new RefreshClassesMetaCommand(swf);
		}
	}
}