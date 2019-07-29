package rasterizer.model;

import format.swf.SWFRoot;

import format.swf.tags.IDefinitionTag;
import format.swf.tags.TagDefineBits;
import format.swf.tags.TagDefineBitsLossless;
import format.swf.SWFTimelineContainer;
import format.swf.instance.MovieClip;
import format.swf.instance.Bitmap;
	
import flash.errors.Error;

import flash.display.DisplayObject;

class SWFClass {
	
	public var name(default, null):String;

	public var root(default, null) : SWFRoot;
	
	public var tag(default, null) : IDefinitionTag;

	public var alias(default, null):String;
	
	/*
	public var scales:Object = {};
    public var checks:Object = {};
    public var anims:Object = {};	
	*/

	


	/*
	 *
	 */
	public function createInstance() : DisplayObject {
		
		if (Std.is(tag, TagDefineBits) || Std.is(tag, TagDefineBitsLossless)) {
			return new Bitmap(cast tag);
		}

		if (Std.is (tag, SWFTimelineContainer)) {
			return new MovieClip (cast tag);
		}

		throw new Error("Create instance failed!");
	}


	/*
	 *
	 */
	public inline function new(root : SWFRoot, tag : IDefinitionTag, name : String, alias : String = null) {
		this.name = name;
		this.root = root;
		this.tag = tag;
		this.alias = alias;
	}

}
