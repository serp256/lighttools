package ru.redspell.rasterizer.commands {
	import flash.filesystem.File;

	import mx.collections.ArrayCollection;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Utils;

	public class RenamePackCommand extends AbstractCommand {
		protected var _pack:SwfsPack;
		protected var _prevName:String;

		public function RenamePackCommand(pack:SwfsPack, prevName:String) {
			_pack = pack;
			_prevName = prevName;
		}

		override public function unsafeExecute():void {
			if (Facade.projDir.resolvePath(_pack.name).exists) {
				var names:Array = [];

				for each (var file:File in Facade.projDir.getDirectoryListing()) {
					if (file.isDirectory) {
						names.push(file.name)
					}
				}

				trace('Utils.getFreeName(_pack.name, names)', Utils.getFreeName(_pack.name, names));

				_pack.name = Utils.getFreeName(_pack.name, names);
				(Facade.app.packsList.dataProvider as ArrayCollection).refresh();
			}

			trace('_prevName', _prevName);
			trace('_pack.name', _pack.name);

			Facade.projDir.resolvePath(_prevName).moveTo(Facade.projDir.resolvePath(_pack.name));
		}
	}
}