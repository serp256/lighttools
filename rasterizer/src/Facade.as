package {
	import flash.filesystem.File;

	import mx.collections.ArrayCollection;

	import ru.nazarov.asmvc.command.ICommand;
	import ru.nazarov.asmvc.command.ICommandError;
	import ru.nazarov.asmvc.command.ICommandManager;
	import ru.redspell.rasterizer.commands.RasterizerCommandManager;
	import ru.redspell.rasterizer.factories.CommandsFactory;
	import ru.redspell.rasterizer.factories.ProjectFactory;
	import ru.redspell.rasterizer.factories.SerializersFactory;
	import ru.redspell.rasterizer.models.Profile;
	import ru.redspell.rasterizer.models.Project;

	public class Facade {
		public static var app:Rasterizer;

		public static var projFactory:ProjectFactory = new ProjectFactory();
		public static var proj:Project;
		public static var projDir:File;
		public static var projSwfsDir:File;
		public static var projOutDir:File;

		public static var commandsManager:ICommandManager = new RasterizerCommandManager();
		public static var commandsFactory:CommandsFactory = new CommandsFactory();

		public static var serializersFactory:SerializersFactory = new SerializersFactory();
		public static var profiles:ArrayCollection = new ArrayCollection([ Profile.create('default', 1) ]);
		public static var profile:Profile = profiles.getItemAt(0) as Profile;

		public static function runCommand(command:ICommand):void {
			var error:ICommandError = command.execute();

			if (error) {
				if (app) {
					app.reportError(error);
				}
			}
		}
	}
}