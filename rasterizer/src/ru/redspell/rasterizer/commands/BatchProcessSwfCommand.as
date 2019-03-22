package ru.redspell.rasterizer.commands 
{
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.system.System;
	import flash.utils.setTimeout;
	import ru.redspell.rasterizer.export.FlattenExporter;
	import ru.redspell.rasterizer.export.IExporter;
	import ru.redspell.rasterizer.flatten.FlattenMovieClip;
	import ru.redspell.rasterizer.flatten.FlattenSprite;
	import ru.redspell.rasterizer.flatten.IFlatten;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.utils.Config;
	
	public class BatchProcessSwfCommand extends InitProjectCommand {
		
		private var isExport:Boolean;
		private var list:Vector.<String> = new <String>[];
		private var total:uint;
		private var current:uint;
		private var outDir:File;
		
		public function BatchProcessSwfCommand(isExport:Boolean):void {
			this.isExport = isExport
			super();
		}
		
		protected function projFile_selectHandler(event:Event):void {
			Facade.app.setStatus('opening project...', false, true);
			setTimeout(openProject, Config.STATUS_REFRESH_TIME, event);
		}
		
		protected function next_Handler(event:Event):void {
			current++;
			Facade.app.setStatus('processing ' + (event.target as Swf).path + ' (' + current + '/' + total + ')', false, true);
			setTimeout(onLoadComplete, Config.STATUS_REFRESH_TIME, event);
		}
		
		override public function unsafeExecute():void {
			var projFile:File = new File();
			
			projFile.addEventListener(Event.SELECT, projFile_selectHandler);
			projFile.browseForDirectory('Select directory containing .swf files');
		}
		
		private function openProject(event:Event):void {
			for each (var file:File in (event.target as File).getDirectoryListing()) {
				if (!file.isDirectory && file.extension == 'swf') {
					list.push(file.nativePath);
					total++;
				}
			}
			if (isExport) {
				var dir:File = (event.target as File).resolvePath('out');
				if (!dir.exists) {
					dir.createDirectory();
				}
				outDir = dir;
			}
			dir = (event.target as File).resolvePath('passed');
			if (!dir.exists) {
				dir.createDirectory();
			}
			dir = (event.target as File).resolvePath('failed');
			if (!dir.exists) {
				dir.createDirectory();
			}
			loadNext();
		}
		
		private function loadNext():void {
			if (list.length > 0) {
				var swf:Swf = Facade.projFactory.getSwf(list.shift());
				swf.addEventListener(Event.COMPLETE, next_Handler);
				swf.loadClasses(true);
			}
		}
		
		private function onLoadComplete(e:Event):void {
			try {
				var swf:Swf = e.target as Swf;
				swf.removeEventListener(Event.COMPLETE, onLoadComplete);
				trace('SWF: loaded', swf.path);
				for each (var cls:SwfClass in swf.classes) {
					var instance:DisplayObject = new cls.definition();
					var flatten:IFlatten = instance is MovieClip ? new FlattenMovieClip() : new FlattenSprite();
					flatten.fromSwfClass(cls, 1);
					trace('flatten', cls.name);
					if (isExport) {
						var clsName:String = cls.alias != null && cls.alias != "" ? cls.alias : cls.name.replace('::', '.');
						var exporter:IExporter = new FlattenExporter();
						exporter.setPath(outDir).export(flatten, clsName);
						trace('exported', cls.name);
						exporter = null;
					}
					instance = null;
					swf.removeClass(cls);
					cls.definition = null;
					cls.swf = null;
					cls.tag = null;
					cls.root = null;
					flatten.dispose();
					System.gc();
				}
				
				var swfFile:File = new File(swf.path);
				var dir:File = swfFile.parent.resolvePath('passed');
				swfFile.moveTo(dir.resolvePath(swfFile.name));
			} catch (e:Error) {
				exporter = null;
				instance = null;
				if (cls != null) {
					swf.removeClass(cls);
					cls.definition = null;
					cls.swf = null;
					cls.tag = null;
					cls.root = null;
				}
				if (flatten != null) {
					flatten.dispose();
				}
				System.gc();
				//Facade.app.reportError(CommandError.create(e, swf.path));
				swfFile = new File(swf.path);
				dir = swfFile.parent.resolvePath('failed');
				swfFile.moveTo(dir.resolvePath(swfFile.name));
				trace('FAILED:', e.name, e.message, swfFile.name);
			}
			if (current == total) {
				Facade.app.setStatus('check completed', true);
			} else {
				loadNext();
			}
		}
		
	}

}