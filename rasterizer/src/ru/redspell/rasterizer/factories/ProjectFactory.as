package ru.redspell.rasterizer.factories {
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.models.SwfsPack;

	public class ProjectFactory {
		public function getProject():Project {
			return new Project();
		}

		public function getSwfPack(name:String):SwfsPack {
			var instance:SwfsPack = new SwfsPack();
			instance.name = name;

			return instance;
		}

		public function getSwf(path:String, checked:Boolean = true, animated:Boolean = true):Swf {
			var instance:Swf = new Swf();

			instance.path = path;
			instance.checked = checked;
			instance.animated = animated;

			return instance;
		}

		public function getSwfClass(definition:Class, name:String, checked:Boolean = true, animated:Boolean = true):SwfClass {
			var instance:SwfClass = new SwfClass();

			instance.definition = definition;
			instance.name = name;
			instance.checked = checked;
			instance.animated = animated;

			return instance;
		}
	}
}