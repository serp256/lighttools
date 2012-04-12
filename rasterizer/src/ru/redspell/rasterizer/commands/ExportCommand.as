package ru.redspell.rasterizer.commands {
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.filesystem.File;
	import flash.utils.setTimeout;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.nazarov.asmvc.command.CommandError;
	import ru.redspell.rasterizer.export.FlattenExporter;
	import ru.redspell.rasterizer.export.IExporter;
	import ru.redspell.rasterizer.export.StaticExporter;
	import ru.redspell.rasterizer.flatten.FlattenMovieClip;
	import ru.redspell.rasterizer.flatten.FlattenSprite;
	import ru.redspell.rasterizer.flatten.IFlatten;
	import ru.redspell.rasterizer.models.Profile;
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;
	import ru.redspell.rasterizer.utils.Utils;

	public class ExportCommand extends AbstractCommand {
		protected var _packIdx:int = -1;
		protected var _swfIdx:int = -1;
		protected var _clsIdx:int = -1;
		protected var _proj:Project;
		protected var _pack:SwfsPack;
		protected var _swf:Swf;
		protected var _packDir:File;
		protected var _classesExported:uint = 0;
		protected var _classesTotal:uint = 0;

		public function ExportCommand(proj:Project) {
			_proj = proj;
		}

		protected function exportClass(cls:SwfClass):void {
			var clsName:String = cls.name.replace('::', '.');
			var clsDir:File = _packDir.resolvePath(clsName);

			if (clsDir.exists) {
				clsDir.deleteDirectory(true);
			}

			clsDir.createDirectory();

			var instance:DisplayObject = new cls.definition();
			var animated:Boolean = cls.animated && cls.swf.animated;

			Utils.traceObj(instance as DisplayObjectContainer);

			var flatten:IFlatten = (instance is MovieClip) && animated ? new FlattenMovieClip() : new FlattenSprite();
			var scales:Object = cls.scales;
			var profile:Profile = Facade.profile;

			trace(clsName, scales.hasOwnProperty(profile.label) ? scales[profile.label] : profile.scale);

			flatten.fromDisplayObject(instance, scales.hasOwnProperty(profile.label) ? scales[profile.label] : profile.scale);

			try {
				var exporter:IExporter = new FlattenExporter();
				exporter.setPath(_packDir).export(flatten, clsName);
			} catch (e:Error) {
				var errorText:String = e.errorID + ': ' + e.message;
				Facade.app.reportError(CommandError.create(e, String(this)));

				return;
			}

			_classesExported++;
			exportNextClass();
		}

		protected function exportNextClass():void {
			if (++_clsIdx < _swf.length) {
				var cls:SwfClass = _swf.getItemAt(_clsIdx) as SwfClass;

				trace('\t' + cls.name);

				if (cls.checked) {
					trace('Exporting pack ' + _pack.name + ' swf ' + _swf.path + ' class ' + cls.name + ' (' + _classesExported + '/' + _classesTotal + ')');
					Facade.app.setStatus('Exporting pack ' + _pack.name + ' swf ' + _swf.path + ' class ' + cls.name + ' (' + _classesExported + '/' + _classesTotal + ')', false, true);
					setTimeout(exportClass, Config.STATUS_REFRESH_TIME, cls);
				} else {
					exportNextClass();
				}
			} else {
				exportNextSwf();
			}
		}

		protected function exportNextSwf():void {
			if (++_swfIdx < _pack.length) {
				_swf = _pack.getItemAt(_swfIdx) as Swf;

				//if (_swf.checked) {
				//	_clsIdx = -1;
				//	exportNextClass();
				//} else {
				//	exportNextSwf();
				//}
				_clsIdx = -1;
				exportNextClass();
			} else {
				exportNextPack();
			}
		}

		protected function exportNextPack():void {
			if (++_packIdx < _proj.length) {
				_pack = _proj.getItemAt(_packIdx) as SwfsPack;
				_swfIdx = -1;
				_packDir = Facade.projOutDir.resolvePath(Facade.profile.label).resolvePath(_pack.name);

				if (_pack.checked) {
					if (_packDir.exists) {
						_packDir.deleteDirectory(true);
					}

					_packDir.createDirectory();

					exportNextSwf();
				} else {
					exportNextPack();
				}
			} else {
				Facade.app.setStatus('Export complete', true);
			}
		}

		protected function calcTotalClassesNum():void {
			for each (var pack:SwfsPack in _proj) {
				if (!pack.checked) {
					continue;
				}

				for each (var swf:Swf in pack) {
					//if (!swf.checked) {
					//	continue;
					//}
					//
					for each (var cls:SwfClass in swf) {
						if (cls.checked) {
							_classesTotal++;
						}
					}
				}
			}
		}

		override public function unsafeExecute():void {
			calcTotalClassesNum();
			exportNextPack();
		}
	}
}