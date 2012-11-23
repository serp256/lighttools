package ru.redspell.rasterizer.utils {
	import flash.display.DisplayObjectContainer;

    import ru.redspell.rasterizer.models.Profile;
    import ru.redspell.rasterizer.models.Swf;
    import ru.redspell.rasterizer.models.SwfClass;

    import ru.redspell.rasterizer.models.SwfsPack;

    public class Utils {
		public static function traceObj(obj:DisplayObjectContainer, indentSize:uint = 0):void {
			var indent:String = '';

			while (indent.length < indentSize) { indent += '\t'; }

			for (var i:uint = 0; i < obj.numChildren; i++) {
				var child:* = obj.getChildAt(i);

				if (child) {
					trace(indent + child + ' ' + (child.hasOwnProperty('name') ? child.name : 'noname'));

					if (child is DisplayObjectContainer) {
						traceObj(child as DisplayObjectContainer, indentSize + 1);
					}
				} else {
					trace('child is null');
				}
			}
		}

		public static function getFreeName(name:String, names:Array):String {
			var newNameRegex:RegExp = new RegExp('^' + name + '(_([\\d]+))?$');
			var taken:Object = {};

			for each (var _name:String in names) {
				var matches:Array = newNameRegex.exec(_name);

				if (matches) {
					if (matches[2]) {
						taken[matches[2]] = 1;
					} else {
						taken['0'] = 1;
					}
				}
			}

			if (!taken.hasOwnProperty('0')) {
				return name;
			} else {
				var i:uint = 0;
				while (taken.hasOwnProperty(String(++i))) {}

				return name + '_' + String(i);
			}
		}

		public static function objIsEmpty(obj:Object):Boolean {
			for (var key:* in obj) {
				return false;
			}

			return true;
		}

        public static function getPackScale(pack:SwfsPack, profile:Profile = null):Number {
            var scales:Object = pack.scales;
            var prof:Profile = profile != null ? profile : Facade.profile;
            var profLbl:String = prof.label;

            return scales.hasOwnProperty(profLbl) ? Number(scales[profLbl]) : prof.scale;
        }

        public static function getSwfScale(swf:Swf, profile:Profile = null):Number {
            var scales:Object = swf.scales;
            var prof:Profile = profile != null ? profile : Facade.profile;
            var profLbl:String = prof.label;

            return scales.hasOwnProperty(profLbl) ? Number(scales[profLbl]) : getPackScale(swf.pack, profile);
        }

        public static function getClsScale(cls:SwfClass, profile:Profile = null):Number {
            var scales:Object = cls.scales;
            var prof:Profile = profile != null ? profile : Facade.profile;
            var profLbl:String = prof.label;

            return scales.hasOwnProperty(profLbl) ? Number(scales[profLbl]) : getSwfScale(cls.swf, profile);
        }
	}
}