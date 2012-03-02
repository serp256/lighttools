package ru.redspell.rasterizer.commands {
	import com.adobe.serialization.json.JSON;

	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.FileFilter;
	import flash.utils.setTimeout;

	import ru.nazarov.binstore.BinStore;
	import ru.nazarov.binstore.IBinStore;
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class OpenProjectCommand extends InitProjectCommand {
		protected var _totalSwfs:uint = 0;
		protected var _loadedSwfs:uint = 0;

		protected function swf_completeHandler(event:Event = null):void {
			if (++_loadedSwfs == _totalSwfs) {
				Facade.app.setStatus('project opened', true);
			} else {
				var swf:Swf = event.target as Swf;
				var meta:Object = getMetaObj(new File(swf.path + Config.META_EXT));

				trace(swf.path + Config.META_EXT, meta);

				if (!meta.empty) {
					for each (var cls:SwfClass in swf.classes) {
						if (meta.hasOwnProperty(cls.name)) {
							var clsMeta:Object = meta[cls.name];

							cls.checked = clsMeta.hasOwnProperty('checked') ? clsMeta['checked'] : true;
							cls.animated = clsMeta.hasOwnProperty('animated') ? clsMeta['animated'] : true;
						}
					}
				}

				Facade.app.setStatus('loading swfs (' + _loadedSwfs + '/' + _totalSwfs + ')', true);
			}
		}

		protected function getMetaObj(metaFile:File):Object {
			var metaObj:Object = { empty:true };

			if (metaFile.exists) {
				var fs:FileStream = new FileStream();
				fs.open(metaFile, FileMode.READ);
				metaObj.empty = false;
				metaObj = JSON.decode(fs.readUTFBytes(fs.bytesAvailable));
				fs.close();
			}

			return metaObj;
		}

		protected function openProject(event:Event):void {
			//var projFile:File = event.target as File;
			//
			//var store:IBinStore = new BinStore();
			//store.read(projFile, Config.ENDIAN);
			//
			//var projDir:File = projFile.parent;
			//var swfsDir:File = projDir.resolvePath(Config.DEFAULT_SWFS_DIR);
			//var outDir:File = projDir.resolvePath(Config.DEFAULT_OUT_DIR);
			//
			//initProject(Facade.serializersFactory.getProjectSerializer().deserialize(store.getChunkAt(0).bytes), projDir, swfsDir, outDir);
			//
			//for each (var pack:SwfsPack in Facade.proj) {
			//	for each (var swf:Swf in pack) {
			//		swf.loadClasses(Facade.projSwfsDir, false);
			//	}
			//}

			var projDir:File = event.target as File;
			var swfsDir:File = projDir.resolvePath(Config.DEFAULT_SWFS_DIR);
			var outDir:File = projDir.resolvePath(Config.DEFAULT_OUT_DIR);
			var proj:Project = new Project();

			for each (var dir:File in projDir.getDirectoryListing()) {
				if (!dir.isDirectory || (dir.name == Config.DEFAULT_OUT_DIR)) {
					continue;
				}

				var pack:SwfsPack = Facade.projFactory.getSwfPack(dir.name);

				for each (var swfFile:File in dir.getDirectoryListing()) {
					if (swfFile.isDirectory || swfFile.extension != 'swf') {
						continue;
					}

					var swf:Swf = Facade.projFactory.getSwf(swfFile.nativePath);

					swf.addEventListener(Event.COMPLETE, swf_completeHandler);
					swf.loadClasses(dir);

					pack.addSwf(swf);

					_totalSwfs++;
				}

				var meta:Object = getMetaObj(dir.resolvePath(Config.META_FILENAME));

				if (!meta.empty) {
					for each (swf in pack.swfs) {
						swf.animated = meta.hasOwnProperty(swf.filename) ? meta[swf.filename].animated : true;
					}
				}

				proj.addPack(pack);
			}

			meta = getMetaObj(projDir.resolvePath(Config.META_FILENAME));

			if (!meta.empty) {
				for each (pack in proj.packs) {
					trace('meta.hasOwnProperty(pack.name) ? meta[pack.name].checked : true', meta.hasOwnProperty(pack.name) ? meta[pack.name].checked : true);
					pack.checked = meta.hasOwnProperty(pack.name) ? meta[pack.name].checked : true;
				}
			}

			initProject(proj, projDir, swfsDir, outDir);

			if (_totalSwfs == 0) {
				_totalSwfs = 1;
				swf_completeHandler();
			}
		}

		protected function projFile_selectHandler(event:Event):void {
			Facade.app.setStatus('opening project...', false, true);
			setTimeout(openProject, Config.STATUS_REFRESH_TIME, event);
		}

		override public function unsafeExecute():void {
			var projFile:File = new File();

			projFile.addEventListener(Event.SELECT, projFile_selectHandler);
			projFile.browseForDirectory('Select rasterizer directory');
		}
	}
}