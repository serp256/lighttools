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
	import ru.redspell.rasterizer.flatten.IFlatten;

	public class FlattenExporter extends BaseExporter implements IExporter {
		protected function exportSprite(obj:FlattenSprite, className:String, dir:File = null, write:Boolean = true):Object {
			var meta:Object = { type:'sprite' };
			var childs:Array = [];

			dir = dir == null ? getDir(className) : dir;

			for each (var child:IFlatten in obj.childs) {
				if (child is FlattenImage) {
					var img:FlattenImage = child as FlattenImage;

					var binary:ByteArray = PNGEncoder.encode(img);
					var hash:String = SHA1.hashBytes(binary);
					var imgFile:File = new File(dir.resolvePath(hash + '.png').nativePath);

					if (!imgFile.exists) {
						var s:FileStream = new FileStream();

						s.open(imgFile, FileMode.WRITE);
						s.writeBytes(binary);
						s.close();
					}

					childs.push({
						name:img.name,
						x:img.matrix.tx,
						y:img.matrix.ty,
						type:'image',
						file:dir.getRelativePath(imgFile)
					});
				} else {
					var box:FlattenSprite = child as FlattenSprite;

					childs.push({
						name:box.name,
						x:box.transform.matrix.tx,
						y:box.transform.matrix.ty,
						type:'box'
					});
				}
			}

			meta.children = childs;

			if (obj.label && obj.label != '') {
				meta.label = obj.label;
			}

			if (write) {
				writeMeta(dir, meta);
			}

			return meta;
		}

		override public function export(obj:Object, className:String):IExporter {
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

			return this;
		}
	}
}