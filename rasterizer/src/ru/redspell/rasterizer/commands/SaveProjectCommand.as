package ru.redspell.rasterizer.commands {
	import flash.utils.ByteArray;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.nazarov.binstore.BinStore;
	import ru.nazarov.binstore.Chunk;
	import ru.nazarov.binstore.ChunkFactory;
	import ru.nazarov.binstore.IBinStore;
	import ru.nazarov.binstore.IChunk;
	import ru.redspell.rasterizer.utils.Config;

	public class SaveProjectCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			var binary:ByteArray = Facade.serializersFactory.getProjectSerializer().serialize(Facade.proj);
			var store:IBinStore = new BinStore()

			store.addChunk(ChunkFactory.createChunk(binary));
			store.write(Facade.projDir.resolvePath(Facade.projDir.name + Config.PROJECT_FILE_EXT), Config.ENDIAN);
		}
	}
}