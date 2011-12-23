package ru.redspell.rasterizer.export {
	import com.adobe.crypto.SHA1;
	import com.adobe.images.PNGEncoder;
	import com.adobe.serialization.json.JSON;

	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	import ru.redspell.rasterizer.flatten.FlattenImage;
	import ru.redspell.rasterizer.flatten.FlattenMovieClip;
	import ru.redspell.rasterizer.flatten.FlattenSprite;

	public class Exporter {
		protected var _dir:File;

		public function Exporter(path:Object) {
			if (path is File) {
				_dir = path as File;
			} else if (path is String) {
				_dir = new File(String(path));
			} else {
				throw new Error('Expected path as flash.filesystem.File or String');
			}
		}

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

		protected function exportSprite(obj:FlattenSprite, className:String, dir:File = null, write:Boolean = true):Object {
			var meta:Object = { type:'sprite' };
			var imgs:Array = [];

			dir = dir == null ? getDir(className) : dir;

			for each (var img:FlattenImage in obj.childs) {
				var binary:ByteArray = PNGEncoder.encode(img);
				var hash:String = SHA1.hashBytes(binary);
				var imgFile:File = new File(dir.resolvePath(hash + '.png').nativePath);

				if (!imgFile.exists) {
					var s:FileStream = new FileStream();

					s.open(imgFile, FileMode.WRITE);
					s.writeBytes(binary);
					s.close();
				}

				imgs.push({
					//name:img.name,
					x:img.matrix.tx,
					y:img.matrix.ty,
					type:'image',
					file:dir.getRelativePath(imgFile)
				})
			}

			meta.children = imgs;

			if (obj.label && obj.label != '') {
				meta.label = obj.label;
			}

			if (write) {
				writeMeta(dir, meta);
			}

			return meta;
		}

		public function export(obj:Object, className:String):void {
			var dir:File = getDir(className);

			if (obj is FlattenSprite) {
				exportSprite(obj as FlattenSprite, className, dir, true);
			} else if (obj is FlattenMovieClip) {
				var meta:Object = { type:'clip' };
				var frames:Array = [];

				for each (var frame:FlattenSprite in (obj as FlattenMovieClip).frames) {
					frames.push(exportSprite(frame, className, dir, false));
				}

				meta.frames = frames;
				writeMeta(dir, meta);
			} else {
				throw new Error('Expected obj as FlattenSprite or FlattenMovieClip');
			}
		}
	}
}