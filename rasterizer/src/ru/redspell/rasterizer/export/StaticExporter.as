package ru.redspell.rasterizer.export {
	import com.adobe.crypto.SHA1;
	import com.adobe.images.PNGEncoder;

	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;

	public class StaticExporter extends BaseExporter implements IExporter {
		override public function export(obj:Object, className:String):IExporter {
			if (obj is DisplayObject) {
				var displayObj:DisplayObject = obj as DisplayObject;

				if (displayObj is MovieClip) {
					(displayObj as MovieClip).gotoAndStop(0);
				}

				var rect:Rectangle = displayObj.getBounds(displayObj);
				var img:BitmapData = new BitmapData(rect.width, rect.height, true, 0x00000000);
				var dir:File = getDir(className);

				img.draw(displayObj, new Matrix(1, 0, 0, 1, -rect.x, -rect.y));

				var clipRect:Rectangle = img.getColorBoundsRect(0xff000000, 0x00000000, false);

				if (clipRect.isEmpty()) {
					var clipped:BitmapData = img;
				} else {
					clipped = new BitmapData(clipRect.width, clipRect.height, true, 0x00000000);
					clipped.copyPixels(img, clipRect, new Point(0, 0));
				}

				var binary:ByteArray = new ByteArray();
				binary = PNGEncoder.encode(clipped);

				var imgFile:File = new File(dir.resolvePath(SHA1.hashBytes(binary) + '.png').nativePath);
				var s:FileStream = new FileStream();

				s.open(imgFile, FileMode.WRITE);
				s.writeBytes(binary);
				s.close();

				writeMeta(dir, {
					type:'sprite',
					children:[
						{ type:'image', x:rect.x, y:rect.y, file:dir.getRelativePath(imgFile) }
					]
				});
			} else {
				throw new Error('Expected obj as DisplayObject');
			}

			return this;
		}
	}
}