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

			MovieClipExt.recStop(clip);

			for (var i:uint = 0; i < clip.totalFrames; i++) {
				_frames.push((new FlattenSprite()).fromDisplayObject(obj));
				MovieClipExt.recNextFrame(clip);
			}

			_curFrame = 0;

			return this;
        }

        public function nextFrame():void {
            _curFrame = ++_curFrame % _frames.length;
            render();
        }

        public function prevFrame():void {
            _curFrame = (_curFrame > 0 ? _curFrame : _frames.length) - 1;
            render();
        }

        public function get frames():Vector.<FlattenSprite> {
            return _frames;
        }

		public function dispose():void {
			for each (var frame:FlattenSprite in _frames) {
				frame.dispose();
			}
		}

		public function render():void {
			while (numChildren) {
				removeChildAt(0);
			}

			var frame:FlattenSprite = _frames[_curFrame];

			frame.render();
			addChild(frame);
		}
	}
}