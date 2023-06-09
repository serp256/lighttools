package ru.redspell.rasterizer.commands {
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.filesystem.File;
    import flash.profiler.profile;
    import flash.utils.setTimeout;
	import ru.redspell.rasterizer.flatten.FlattenImage;

	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.nazarov.asmvc.command.CommandError;
	import ru.redspell.rasterizer.export.FlattenExporter;
	import ru.redspell.rasterizer.export.IExporter;
	import ru.redspell.rasterizer.export.StaticExporter;
	import ru.redspell.rasterizer.flatten.FlattenMovieClip;
	import ru.redspell.rasterizer.flatten.FlattenSprite;
	import ru.redspell.rasterizer.flatten.IFlatten;
    import ru.redspell.rasterizer.models.ClassProfile;
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
        protected var _profiles:Array;
		protected var _pack:SwfsPack;
		protected var _swf:Swf;
		protected var _packDir:File;
		protected var _classesExported:uint = 0;
		protected var _classesTotal:uint = 0;

		public function ExportCommand(proj:Project, profiles:Array = null) {
			_proj = proj;
            _profiles = profiles == null ? [ Facade.profile ] : profiles;
		}

		protected function exportClass(cls:SwfClass):void {
			
			var clsName:String = cls.alias != null && cls.alias != "" ? cls.alias : cls.name.replace('::', '.');
			var clsDir:File = _packDir.resolvePath(clsName);

			if (clsDir.exists) {
				clsDir.deleteDirectory(true);
			}

			clsDir.createDirectory();

			var instance:Object = new cls.definition();
            var profileLbl:String = (_profiles[0] as Profile).label;

			var animated:Boolean = (!cls.anims.hasOwnProperty(profileLbl) || cls.anims[profileLbl]) && cls.swf.animated;

			//Utils.traceObj(instance as DisplayObjectContainer);

			var src:Object = new cls.definition();
			var flatten:IFlatten = instance is MovieClip && animated ? new FlattenMovieClip() : (instance is Sprite ? new FlattenSprite() : new FlattenImage(src.width, src.height, true, 0x00000000));
            //trace('pizdalalahoho');
			//flatten.fromDisplayObject(instance, Utils.getClsScale(cls, _profiles[0]));
			flatten.fromSwfClass(cls, Utils.getClsScale(cls, _profiles[0]));

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
                var profileLbl:String = (_profiles[0] as Profile).label;

				trace('\t' + cls.name);

				if (!cls.checks.hasOwnProperty(profileLbl) || cls.checks[profileLbl]) {
					Facade.app.setStatus('Exporting profile ' + (_profiles[0] as Profile).label + ' pack ' + _pack.name + ' swf ' + _swf.path + ' class ' + cls.name + ' (' + _classesExported + '/' + _classesTotal + ')', false, true);
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
				_packDir = Facade.projOutDir.resolvePath((_profiles[0] as Profile).label).resolvePath(_pack.name);

				if (_pack.checked) {
					if (_packDir.exists) {
						_packDir.deleteDirectory(true);
					}

					_packDir.createDirectory();

					exportNextSwf();
				} else {
					exportNextPack();
				}
			} else if (_profiles.length > 1) {
                _packIdx = -1;
                _profiles = _profiles.slice(1);
                exportNextPack();
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
					for each (var cls:SwfClass in swf) {
                        var clsUnchecksNum:int = 0;

                        for (var clsProfile:String in cls.checks) {
                            if (!cls.checks[clsProfile]) {
                                clsUnchecksNum++;
                            }
                        }

						_classesTotal += Facade.profiles.length - clsUnchecksNum;
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