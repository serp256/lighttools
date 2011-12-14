package ru.redspell.rasterizer.utils {
    import flash.display.DisplayObject;
    import flash.display.MovieClip;
    import flash.display.Shape;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;

    import ru.redspell.rasterizer.flatten.FlattenImage;

    public class MovieClipExt {
		public static function recStop(clip:MovieClip, reset:Boolean = true):MovieClip {
			if (reset) {
                clip.gotoAndStop(0);
            } else {
                clip.stop();
            }

			for (var i:uint = 0; i < clip.numChildren; i++) {
				var child:MovieClip = clip.getChildAt(i) as MovieClip;

				if (child) {
					recStop(child);
				}
			}

			return clip;
		}

		public static function recNextFrame(clip:MovieClip):MovieClip {
			clip.nextFrame();

			for (var i:uint = 0; i < clip.numChildren; i++) {
				var child:MovieClip = clip.getChildAt(i) as MovieClip;

				if (child) {
					recNextFrame(child);
				}
			}

			return clip;
		}

		public static function recPrevFrame(clip:MovieClip):MovieClip {
			clip.prevFrame();

			for (var i:uint = 0; i < clip.numChildren; i++) {
				var child:MovieClip = clip.getChildAt(i) as MovieClip;

				if (child) {
					recPrevFrame(child);
				}
			}

			return clip;
		}
	}
}