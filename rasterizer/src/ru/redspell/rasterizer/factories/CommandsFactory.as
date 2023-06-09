package ru.redspell.rasterizer.factories {
	import ru.nazarov.asmvc.command.ICommandManager;
	import ru.redspell.rasterizer.commands.*;
	import ru.nazarov.asmvc.command.ICommand;
	import ru.redspell.rasterizer.models.Profile;
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class CommandsFactory {
		public function getOpenProjectCommand():ICommand {
			return new OpenProjectCommand();
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

		public function getExportCommand(proj:Project, profiles:Array = null):ICommand {
			return new ExportCommand(proj, profiles);
		}

		public function getRenamePackCommand(pack:SwfsPack, prevName:String):ICommand {
			return new RenamePackCommand(pack, prevName);
		}

		public function getRefreshPackMetaCommand(pack:SwfsPack, save:Boolean = true):ICommand {
			return new RefreshPackMetaCommand(pack, save);
		}

		public function getRefreshSwfMetaCommand(swf:Swf, save:Boolean = true):ICommand {
			return new RefreshSwfMetaCommand(swf, save);
		}

		public function getRefreshClassMetaCommand(cls:SwfClass, save:Boolean = true):ICommand {
			return new RefreshClassMetaCommand(cls, save);
		}

		public function getSaveProjectMetaCommand():ICommand {
			return new SaveProjectMetaCommand();
		}

		public function getSavePackMetaCommand(pack:SwfsPack):ICommand {
			return new SavePackMetaCommand(pack);
		}

		public function getChooseProfileCommand(profile:Profile):ICommand {
			return new ChooseProfileCommand(profile);
		}

		public function getCreateProfileCommand(label:String, scale:Number):ICommand {
			return new CreateProfileCommand(label, scale);
		}
	}
}