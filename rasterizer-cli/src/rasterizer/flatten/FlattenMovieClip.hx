package rasterizer.flatten;

import openfl.errors.Error;
import flash.display.DisplayObject;
import flash.display.MovieClip;
import flash.display.Sprite;

import rasterizer.model.SWFClass;

import format.swf.SWFRoot;
import format.swf.tags.IDefinitionTag;


using Lambda;
using FlattenMovieClip.MovieClipExt;





class FlattenMovieClip extends Sprite implements IFlatten {
        
	private var __frames : Array<FlattenSprite>;

	private var __currentFrame : Int;
			
	public var currentFrame(get, null) : Int;

	public var frames(get, null) : Array<FlattenSprite>;

	public var swf : SWFRoot;

	// если этот флаг выставлен, то мы не применяем маски, а записываем их в мету
	public var preserveTagMasks : Bool;


	/*
	 *
	 */
	public function new() {
		super();
		__currentFrame = 0;
		__frames = [];
	}

	/*
	 *
	 */
	public function fromSwfClass(cls : SWFClass, scale : Float) : IFlatten {
		swf = cls.root;
		return fromDisplayObject(cls.createInstance(), scale, cls.tag);
	}


	/*
	 *
	 */
    public function fromDisplayObject(obj : DisplayObject, scale : Float = 1.0, tag:IDefinitionTag = null):IFlatten {

		if (!Std.is(obj, MovieClip)) {
			throw new Error('Expected obj as MovieClip');
		}

		var clip : MovieClip = cast obj;
		clip.recStop();
		for (i in 1...clip.totalFrames + 1) {
			var frame = new FlattenSprite();
			frame.preserveTagMasks = preserveTagMasks;
			frame.swf = swf;
			frame.fromDisplayObject(clip, scale, tag);			
			frame.label = clip.currentLabel;
			__frames.push(frame);			
			clip.recNextFrame();
		}
		

		__currentFrame = 0;
		return this;
    }


	/* 
	 *
	 */
	private function get_currentFrame() { 
		return __currentFrame; 
	}

	/* 
 	 *
	 */
    public function get_frames() { 
		return __frames; 
	}


	/*
	 *
	 */
	public function goto(frame : Int) {
		__currentFrame = (frame < __frames.length) ? frame : (__frames.length - 1);
	}


	/*
	 *
	 */
    public function nextFrame() {
        __currentFrame = ++__currentFrame % __frames.length;
        render();
    }

	/*
	 *
	 */
    public function prevFrame() {
        __currentFrame = (__currentFrame > 0 ? __currentFrame : __frames.length) - 1;
        render();
    }

	
	/*
	 *
	 */
	public function dispose() {
		__frames.iter(function (f) { f.dispose(); });
	}

	
	/*
	 *
	 */
	public function render() {
		while (numChildren > 0) {
			removeChildAt(0);
		}

		var frame = __frames[__currentFrame];
		frame.render();
		addChild(frame);
	}
}



class MovieClipExt {
	
	/*
	 *
	 */
	public static function recStop(clip : MovieClip, reset : Bool = true) : MovieClip {
		
		if (reset) {
            clip.gotoAndStop(1);
        } else {
            clip.stop();
        }

		
		for (i in 0...clip.numChildren) {		
			var child = clip.getChildAt(i);
			if (Std.is(child, MovieClip)) {				
				var child : MovieClip = cast child;
				child.recStop();
			}
		}

		return clip;
	}

	
	/*
	 *
	 */
	public static function recNextFrame(clip : MovieClip) : MovieClip {
		clip.nextFrame();

		for (i in 0...clip.numChildren) {
			var child = clip.getChildAt(i);
			if (Std.is(child, MovieClip)) {
				var child : MovieClip = cast child;
				child.recNextFrame();
			}
		}

		return clip;
	}


	/*
	 *
	 */
	public static function recPrevFrame(clip : MovieClip) : MovieClip {
		clip.prevFrame();

		for (i in 0...clip.numChildren) {
			var child = clip.getChildAt(i);
			if (Std.is(child, MovieClip)) {
				var child : MovieClip = cast child;
				child.recPrevFrame();
			}
		}
		return clip;
	}
}




