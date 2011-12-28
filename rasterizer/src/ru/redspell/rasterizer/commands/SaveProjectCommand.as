package ru.redspell.rasterizer.commands {
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.nazarov.binstore.BinStore;
	import ru.nazarov.binstore.Chunk;
	import ru.nazarov.binstore.ChunkFactory;
	import ru.nazarov.binstore.IBinStore;
	import ru.nazarov.binstore.IChunk;
	import ru.redspell.rasterizer.utils.Config;

	public class SaveProjectCommand extends AbstractCommand {
		protected var _beforeStatus:String;
		protected var _afterStatus:String;

		public function SaveProjectCommand(beforeStatus:String = null, afterStatus:String = null) {
			_beforeStatus = beforeStatus;
			_afterStatus = afterStatus;
		}

		protected function saveProject():void {
			var binary:ByteArray = Facade.serializersFactory.getProjectSerializer().serialize(Facade.proj);
			var store:IBinStore = new BinStore()

			store.addChunk(ChunkFactory.createChunk(binary));
			store.write(Facade.projDir.resolvePath(Facade.projDir.name + Config.PROJECT_FILE_EXT), Config.ENDIAN);

			Facade.app.setStatus(_afterStatus, true);
		}

		override public function unsafeExecute():void {
			if (_beforeStatus) {
				Facade.app.setStatus(_beforeStatus, false, true);
				setTimeout(saveProject, Config.STATUS_REFRESH_TIME);
			} else {
				saveProject();
			}
		}
	}
}