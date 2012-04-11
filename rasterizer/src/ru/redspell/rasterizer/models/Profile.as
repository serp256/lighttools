package ru.redspell.rasterizer.models {
	public class Profile {
		public var label:String;
		public var scale:Number = 1;

		public static function create(label:String, scale:Number):Profile {
			var instance:Profile = new Profile();

			instance.label = label;
			instance.scale = scale;

			return instance;
		}
	}
}