package ru.redspell.rasterizer.flatten {
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Sprite;

	import ru.redspell.rasterizer.utils.MovieClipExt;
	import ru.redspell.rasterizer.utils.Utils;

	public class FlattenMovieClip extends Sprite implements IFlatten {
        protected var _frames:Vector.<FlattenSprite> = new Vector.<FlattenSprite>();
        protected var _curFrame:int = 0;

        public function fromDisplayObject(obj:DisplayObject):IFlatten {
			var clip:MovieClip = obj as MovieClip;

			if (!clip) {
				throw new Error('Expected obj as MovieClip');
			}

			MovieClipExt.recStop(clip);
			Utils.traceObj(clip);

			for (var i:uint = 1; i <= clip.totalFrames; i++) {
				var frame:FlattenSprite = (new FlattenSprite()).fromDisplayObject(obj) as FlattenSprite;

				frame.label = clip.currentLabel;
				_frames.push(frame);
				MovieClipExt.recNextFrame(clip);
			}

			_curFrame = 0;

			return this;
        }

		public function get curFrame():uint {
			return _curFrame;
		}

		public function goto(frame:uint):void {
			_curFrame = (frame < _frames.length) ? frame : (_frames.length - 1);
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

			trace('_________________rendering frame ' + _curFrame + '_____________________');

			var frame:FlattenSprite = _frames[_curFrame];

			frame.render();
			addChild(frame);
		}
	}
}