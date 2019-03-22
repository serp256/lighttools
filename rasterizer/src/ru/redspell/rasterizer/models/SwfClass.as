package ru.redspell.rasterizer.models {
	import com.codeazur.as3swf.SWF;
	import com.codeazur.as3swf.tags.IDefinitionTag;
	public class SwfClass {
		public var name:String;
        public var alias:String;
		public var definition:Class;
		//public var animated:Boolean = true;
		//public var checked:Boolean = true;
		public var swf:Swf;
		public var scales:Object = {};
        public var checks:Object = {};
        public var anims:Object = {};
		
		public var root:SWF;
		public var tag:IDefinitionTag;
	}
}