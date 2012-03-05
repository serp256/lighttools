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
				var meta:Object = Facade.proj.meta;

				for each (var cls:SwfClass in swf.classes) {
					if (!meta.hasOwnProperty(cls.swf.pack.name)) {
						continue;
					}

					var packMeta:Object = meta[cls.swf.pack.name];

					if (!packMeta.hasOwnProperty(cls.swf.filename)) {
						continue;
					}

					var swfMeta:Object = packMeta[cls.swf.filename];

					if (!swfMeta.hasOwnProperty(cls.name)) {
						continue;
					}

					var clsMeta:Object = swfMeta[cls.name];
					cls.checked = clsMeta.hasOwnProperty('checked') ? clsMeta.checked : true;
					cls.animated = clsMeta.hasOwnProperty('animated') ? clsMeta.animated : true;
				}

				Facade.app.setStatus('loading swfs (' + _loadedSwfs + '/' + _totalSwfs + ')', true);
			}
		}

		protected function getMetaObj(metaFile:File):Object {
			var metaObj:Object = {};

			if (metaFile.exists) {
				var fs:FileStream = new FileStream();
				fs.open(metaFile, FileMode.READ);
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
			var meta:Object = getMetaObj(projDir.resolvePath(Config.META_FILENAME));

			for each (var dir:File in projDir.getDirectoryListing()) {
				if (!dir.isDirectory || (dir.name == Config.DEFAULT_OUT_DIR)) {
					continue;
				}

				var pack:SwfsPack = Facade.projFactory.getSwfPack(dir.name);

				if (meta.hasOwnProperty(dir.name)) {
					var packMeta:Object = meta[dir.name];
					pack.checked = packMeta.hasOwnProperty('checked') ? packMeta.checked : true;
				}

				for each (var swfFile:File in dir.getDirectoryListing()) {
					if (swfFile.isDirectory || swfFile.extension != 'swf') {
						continue;
					}

					var swf:Swf = Facade.projFactory.getSwf(swfFile.nativePath);

					if (packMeta && packMeta.hasOwnProperty(swf.filename)) {
						var swfMeta:Object = packMeta[swf.filename];
						swf.animated = swfMeta.hasOwnProperty('animated') ? swfMeta.aninated : true;
					}

					swf.addEventListener(Event.COMPLETE, swf_completeHandler);
					swf.loadClasses(dir);

					pack.addSwf(swf);

					_totalSwfs++;
				}

				proj.addPack(pack);
			}

			proj.meta = meta;
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