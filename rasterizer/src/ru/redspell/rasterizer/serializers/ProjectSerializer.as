package ru.redspell.rasterizer.serializers {
	import flash.filesystem.File;
	import flash.utils.ByteArray;

	import ru.redspell.rasterizer.factories.ProjectFactory;

	import ru.redspell.rasterizer.models.Project;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Config;

	public class ProjectSerializer {
		public function serialize(proj:Project):ByteArray {
			var binary:ByteArray = new ByteArray();

			binary.endian = Config.ENDIAN;
			binary.writeUnsignedInt(proj.length);

			for each (var pack:SwfsPack in proj.source) {
				binary.writeUTF(pack.name);
				binary.writeBoolean(pack.checked);
				binary.writeUnsignedInt(pack.length);

				for each (var swf:Swf in pack) {
					binary.writeUTF(swf.path);
					binary.writeBoolean(swf.checked);
					binary.writeBoolean(swf.animated);
					binary.writeUnsignedInt(swf.length);

					for each (var cls:SwfClass in swf) {
						binary.writeUTF(cls.name);
						binary.writeBoolean(cls.checked);
						binary.writeBoolean(cls.animated);
					}
				}
			}

			return binary;
		}

		public function deserialize(binary:ByteArray):Project {
			binary.endian = Config.ENDIAN;

			var factory:ProjectFactory = Facade.projFactory;
			var proj:Project = factory.getProject();
			var packsNum:uint = binary.readUnsignedInt();

			for (var i:uint = 0; i < packsNum; i++) {
				var pack:SwfsPack = factory.getSwfPack(binary.readUTF(), binary.readBoolean());
				var swfsNum:uint = binary.readUnsignedInt();

				for (var j:uint = 0; j < swfsNum; j++) {
					var swf:Swf = factory.getSwf(binary.readUTF(), binary.readBoolean(), binary.readBoolean());
					var classesNum:uint = binary.readUnsignedInt();

					for (var k:uint = 0; k < classesNum; k++) {
						var cls:SwfClass = factory.getSwfClass(null, binary.readUTF(), binary.readBoolean(), binary.readBoolean());
						swf.addClass(cls);
					}

					pack.addSwf(swf);
				}

				proj.addPack(pack);
			}

			return proj;
		}
	}
}