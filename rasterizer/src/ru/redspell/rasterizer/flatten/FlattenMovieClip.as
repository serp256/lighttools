package ru.redspell.rasterizer.flatten {
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Sprite;

	import ru.redspell.rasterizer.utils.MovieClipExt;

	public class FlattenMovieClip extends Sprite implements IFlatten {
        protected var _frames:Vector.<FlattenSprite> = new Vector.<FlattenSprite>();
        protected var _curFrame:int = 0;

        public function fromDisplayObject(obj:DisplayObject):IFlatten {
			var clip:MovieClip = obj as MovieClip;

			if (!clip) {
				throw new Error('Expected obj as MovieClip');
			}

            _curFrame = -1;
			MovieClipExt.recStop(clip);

			for (var i:uint = 0; i < clip.totalFrames; i++) {
				_frames.push((new FlattenSprite()).fromDisplayObject(obj));
				MovieClipExt.recNextFrame(clip);
			}

			return this;
        }

        protected function refresh():void {
            while (numChildren) {
                removeChildAt(0);
            }

            for each (var layer:FlattenImage in _frames[_curFrame].childs) {
                var bmp:Bitmap = new Bitmap(layer);

                bmp.transform.matrix = layer.matrix;
                addChild(bmp);
            }
        }

        public function nextFrame():void {
            _curFrame = ++_curFrame % _frames.length;
            refresh();
        }

        public function prevFrame():void {
            _curFrame = (_curFrame > 0 ? _curFrame : _frames.length) - 1;
            refresh();
        }

        public function get frames():Vector.<FlattenSprite> {
            return _frames;
        }

		public function getMeta():Object {
			return null;
		}

		public function dispose():void {
			for each (var frame:FlattenSprite in _frames) {
				frame.dispose();
			}
		}
	}
}