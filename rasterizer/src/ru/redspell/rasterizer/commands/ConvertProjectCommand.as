package ru.redspell.rasterizer.commands {
	import com.maccherone.json.JSON;

	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	import ru.nazarov.asmvc.command.AbstractCommand;

	import ru.nazarov.binstore.BinStore;
	import ru.nazarov.binstore.IBinStore;
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;
	import ru.redspell.rasterizer.utils.Utils;

	public class ConvertProjectCommand extends AbstractCommand {
		override public function unsafeExecute():void {
			var src:File = new File('/Users/andrey/projects/mobile-farm/rasterizer/rasterizer.rst');
			var out:File = new File('/Users/andrey/Desktop/mobile-farm');

			if (out.exists) {
				out.deleteDirectory(true);
			}

			var store:IBinStore = new BinStore();
			store.read(src, Config.ENDIAN);

			var projDir:File = src.parent;
			var swfsDir:File = projDir.resolvePath(Config.DEFAULT_SWFS_DIR);
			var outDir:File = projDir.resolvePath(Config.DEFAULT_OUT_DIR);
			var proj:Project = Facade.serializersFactory.getProjectSerializer().deserialize(store.getChunkAt(0).bytes);

			outDir.copyTo(out.resolvePath('out'));

			var packsMeta:Object = {};

			for each (var pack:SwfsPack in proj.packs) {
				var packMeta:Object = {};
				trace(pack.name);

				if (!pack.checked) {
					packMeta = { checked:false };
				}

				var packDir:File = out.resolvePath(pack.name);
				packDir.createDirectory();

				for each (var swf:Swf in pack.swfs) {
					var swfMeta:Object = {};
					trace('\t', swf.path);

					if (!swf.animated) {
						swfMeta = { animated:false };
					}

					swfsDir.resolvePath(swf.path).copyTo(packDir.resolvePath(swf.path));

					for each (var cls:SwfClass in swf.classes) {
						var clsMeta:Object = {};

						if (!cls.checked || !cls.animated) {
							if (!cls.checked) {
								clsMeta = { checked:false };

								var clsDir:File = out.resolvePath('out').resolvePath(pack.name).resolvePath(cls.name.replace('::', '.'));

								if (clsDir.exists) {
									clsDir.deleteDirectory(true);
								}
							}

							if (!cls.animated) {
								if (clsMeta.hasOwnProperty(cls.name)) {
									clsMeta['animated'] = false;
								} else {
									clsMeta = { animated:false };
								}
							}
						}

						if (!Utils.objIsEmpty(clsMeta)) {
							swfMeta[cls.name] = clsMeta;
						}

						trace('\t\t', cls.name);
					}

					if (!Utils.objIsEmpty(swfMeta)) {
						packMeta[swf.path] = swfMeta;
					}
				}

				if (!Utils.objIsEmpty(packMeta)) {
					packsMeta[pack.name] = packMeta;
				}
			}

			if (!Utils.objIsEmpty(packsMeta)) {
				var fs:FileStream = new FileStream();
				fs.open(out.resolvePath(Config.META_FILENAME), FileMode.WRITE);
				fs.writeUTFBytes(JSON.encode(packsMeta));
				fs.close();
			}
		}
	}
}