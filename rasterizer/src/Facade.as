package {
	import flash.filesystem.File;

	import ru.nazarov.asmvc.command.ICommand;
	import ru.nazarov.asmvc.command.ICommandError;
	import ru.nazarov.asmvc.command.ICommandManager;
	import ru.redspell.rasterizer.commands.RasterizerCommandManager;
	import ru.redspell.rasterizer.factories.CommandsFactory;
	import ru.redspell.rasterizer.factories.ProjectFactory;
	import ru.redspell.rasterizer.factories.SerializersFactory;
	import ru.redspell.rasterizer.models.Project;

	public class Facade {
		public static var app:Rasterizer;

		public static var projFactory:ProjectFactory = new ProjectFactory();
		public static var proj:Project;
		public static var projDir:File = new File('/Users/andrey/Desktop/xyupizda');
		public static var projSwfsDir:File;
		public static var projOutDir:File;

		public static var commandsManager:ICommandManager = new RasterizerCommandManager();
		public static var commandsFactory:CommandsFactory = new CommandsFactory();

		public static var serializersFactory:SerializersFactory = new SerializersFactory();

		public static function runCommand(command:ICommand):void {
			var error:ICommandError = command.execute();

			if (error) {
				if (app) {
					app.reportError(error);
				}

				trace(error.getStack());
			}
		}
	}
}