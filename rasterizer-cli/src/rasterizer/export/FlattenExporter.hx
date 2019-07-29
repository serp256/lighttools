package rasterizer.export;

import sys.FileSystem;
import openfl.display.PNGEncoderOptions;
import sys.io.File;
import rasterizer.flatten.FlattenImage;
import rasterizer.flatten.FlattenMovieClip;
import rasterizer.flatten.FlattenSprite;
import rasterizer.flatten.IFlatten;

import haxe.crypto.Sha1;

import haxe.io.Path;

class FlattenExporter extends BaseExporter implements IExporter {

	public function new() {
	}

	private function exportSprite(obj:FlattenSprite, className:String, dir : Path = null, write : Bool = true) : Dynamic {
		
		var meta : Dynamic = { type:'sprite' };
		var children : Array<Dynamic> = [];

		if (dir == null) {
			dir = getDir(className);
		}

		for (child in obj.children) {

			if (Std.is(child, FlattenImage)) {
				
				var img : FlattenImage = cast child;
				var binary = img.encode(img.rect, new PNGEncoderOptions(false));			
				var hash = Sha1.encode(binary.toString());
				var file = Path.join([ dir.toString(), '${hash}.png' ]);

				if (!FileSystem.exists(file)) {
					File.saveBytes(file, binary);
				}

				children.push({ name : img.name, x : img.matrix.tx, y : img.matrix.ty, type : "image", file : Path.withoutDirectory(file) });

			} else {				
				var box:FlattenSprite = cast child;
				children.push({ name : box.name, x : box.transform.matrix.tx, y : box.transform.matrix.ty, type : "box"	});
			}
		}

		meta.children = children;
		if (obj.label != null && obj.label != "") {
			meta.label = obj.label;
		}

		if (write) {
			writeMeta(dir, meta);
		}
		
		return meta;
	}


	/*
	 *
	 */
	override public function export(obj:IFlatten, className:String):IExporter {
		
		var dir = getDir(className);
		
		if (Std.is(obj, FlattenSprite)) {

			exportSprite(cast obj, className, dir, true);
		
		} else if (Std.is(obj, FlattenMovieClip)) {
			
			var meta : Dynamic = { type : "clip" };
			var frames = [];
			var obj : FlattenMovieClip = cast obj;
			
			for (frame in obj.frames) {
				frames.push(exportSprite(frame, className, dir, false));
			}
			
			meta.frames = frames;
			writeMeta(dir, meta);
		
		} else {
			
			var meta : Dynamic = { type : "sprite" };			
			var img : FlattenImage = cast obj;
			
			var binary = img.encode(img.rect, new PNGEncoderOptions(false));			
			var hash = Sha1.encode(binary.toString());
			var file = Path.join([ dir.toString(), '${hash}.png' ]);

			if (!FileSystem.exists(file)) {
				File.saveBytes(file, binary);
			}
			
			meta.children = [{ name : img.name, x : img.matrix.tx, y : img.matrix.ty, type : 'image', file : Path.withoutDirectory(file) }];
			
			writeMeta(dir, meta);
		}
		return this;
	}
}
