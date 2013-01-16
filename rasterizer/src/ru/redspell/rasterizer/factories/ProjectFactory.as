package ru.redspell.rasterizer.factories {
	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.models.SwfsPack;

	public class ProjectFactory {
		public function getProject():Project {
			return new Project();
		}

		public function getSwfPack(name:String, checked:Boolean = true):SwfsPack {
			var instance:SwfsPack = new SwfsPack();

			instance.name = name;
			instance.checked = checked;

			return instance;
		}

		public function getSwf(path:String, animated:Boolean = true):Swf {
			var instance:Swf = new Swf();

			instance.path = path;
			instance.animated = animated;

			return instance;
		}

		public function getSwfClass(definition:Class, name:String):SwfClass {
			var instance:SwfClass = new SwfClass();

			instance.definition = definition;
			instance.name = name;
            instance.checks = {};
            instance.anims = {};
			//instance.checked = checked;
			//instance.animated = animated;

			return instance;
		}
	}
}