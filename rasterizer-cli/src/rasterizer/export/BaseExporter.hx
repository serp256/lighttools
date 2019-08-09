package rasterizer.export;
	
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import rasterizer.flatten.IFlatten;
	
class BaseExporter implements IExporter {

	private var __dir:Path;

	/*
	 *
	 */
	private function getDir(className : String) : Path {
		var path =  Path.join( [__dir.toString(), className] );

		if (FileSystem.exists(path)) {
			if (FileSystem.isDirectory(path)) {
				Main.removeDirectory(path);
			} else {
				FileSystem.deleteFile(path);
			}
		}

		FileSystem.createDirectory(path);		
		return new Path(Path.addTrailingSlash(path));
	}



	/*
	 * 
	 */
	private function writeMeta(dir : Path, meta : Dynamic) {
		var file = Path.join([ dir.toString(), "meta.json"]);
		File.saveContent(file, Json.stringify(meta));
	}

	/*
	 *
	 */
	public function export(obj : IFlatten, className : String):IExporter {
		return this;
	}
	
	/*
	 * Путь не включает имя класса
	 */
	public function setPath(path : Path) : IExporter {
		__dir = path;
		return this;
	}

}

