package ru.redspell.rasterizer.factories {
	import ru.redspell.rasterizer.commands.*;
	import ru.nazarov.asmvc.command.ICommand;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfsPack;

	public class CommandsFactory {
		public function getNewProjectCommand():ICommand {
			return new NewProjectCommand();
		}

		public function getOpenProjectCommand():ICommand {
			return new OpenProjectCommand();
		}

		public function getSaveProjectCommand():ICommand {
			return new SaveProjectCommand();
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
	}
}