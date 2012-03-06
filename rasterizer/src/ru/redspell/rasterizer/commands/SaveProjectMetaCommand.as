package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.nazarov.asmvc.command.AbstractMacroCommand;
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class SaveProjectMetaCommand extends AbstractMacroCommand {
		public function SaveProjectMetaCommand() {
			for each (var pack:SwfsPack in Facade.proj.packs) {
				addSubcommand(new SavePackMetaCommand(pack));
			}
		}
	}
}