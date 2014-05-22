package vo {
	public class VOQuest{
		public var
			qname:String,
//			auto_programmable:Boolean,
			prev:Array /*of String or [String, int]*/,
			level:uint,
//			story:String,
//			icon:String,
			nesting_level:int,
			line:int = -1,
/*			prize:Array,
			targets:Array,
			drop:Array,
			monsters_probability:Object,
			story_line:String,
			story_line_order:int,
			story_line_close:*,
			disabled:Boolean,
			refusal:Boolean,
			share_type:*,  */
			//maxnestinglevel:int = 0,
			prevQ:Array = [],
			nextQ:Array = [],
			likeness:Object = {}
		;
	}
}
