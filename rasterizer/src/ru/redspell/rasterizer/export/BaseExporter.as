package ru.redspell.rasterizer.export {
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	public class BaseExporter implements IExporter {
		protected var _dir:File;

		protected function getDir(className:String):File {
			var dir:File = _dir.resolvePath(className);

			if (dir.exists) {
				dir.isDirectory ? dir.deleteDirectory(true) : dir.deleteFile();
			}

			dir.createDirectory();

			return dir;
		}

		protected function writeMeta(dir:File, meta:Object):void {
			var metaFile:File = new File(dir.resolvePath('meta.json').nativePath);
			var fs:FileStream = new FileStream();

			fs.open(metaFile, FileMode.WRITE);
			fs.writeUTFBytes(JSON.encode(meta));
			fs.close();
		}

		public function export(obj:Object, className:String):IExporter {
			return this;
		}

		public function setPath(path:Object):IExporter {
			if (path is File) {
				_dir = path as File;
			} else if (path is String) {
				_dir = new File(String(path));
			} else {
				throw new Error('Expected path as flash.filesystem.File or String');
			}

			return this;
		}
	}
}