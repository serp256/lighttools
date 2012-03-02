package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

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

			var packsMeta:Object = {};

			//outDir.copyTo(out.resolvePath('out'));

			for each (var pack:SwfsPack in proj.packs) {
				trace(pack.name);

				if (!pack.checked) {
					packsMeta[pack.name] = { checked:false };
				}

				var packDir:File = out.resolvePath(pack.name);
				packDir.createDirectory();

				var swfsMeta:Object = {};

				for each (var swf:Swf in pack.swfs) {
					trace('\t', swf.path);

					if (!swf.animated) {
						swfsMeta[swf.path] = { animated:false };
					}

					swfsDir.resolvePath(swf.path).copyTo(packDir.resolvePath(swf.path));

					var clsMeta:Object = {};

					for each (var cls:SwfClass in swf.classes) {
						if (!cls.checked || !cls.animated) {
							if (!cls.checked) {
								clsMeta[cls.name] = { checked:false };

								var clsDir:File = out.resolvePath('out').resolvePath(pack.name).resolvePath(cls.name.replace('::', '.'));

								if (clsDir.exists) {
									clsDir.deleteDirectory(true);
								}
							}

							if (!cls.animated) {
								if (clsMeta.hasOwnProperty(cls.name)) {
									clsMeta[cls.name]['animated'] = false;
								} else {
									clsMeta[cls.name] = { animated:false };
								}
							}
						}

						trace('\t\t', cls.name);
					}

					fs = new FileStream();
					fs.open(packDir.resolvePath(swf.path + Config.META_EXT), FileMode.WRITE);
					fs.writeUTFBytes(JSON.encode(clsMeta));
					fs.close();
				}

				var fs:FileStream = new FileStream();
				fs.open(packDir.resolvePath(Config.META_FILENAME), FileMode.WRITE);
				fs.writeUTFBytes(JSON.encode(swfsMeta));
				fs.close();
			}

			fs = new FileStream();
			fs.open(out.resolvePath(Config.META_FILENAME), FileMode.WRITE);
			fs.writeUTFBytes(JSON.encode(packsMeta));
			fs.close();
		}
	}
}