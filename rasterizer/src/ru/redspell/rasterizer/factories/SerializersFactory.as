package ru.redspell.rasterizer.factories {
	import ru.redspell.rasterizer.serializers.ProjectSerializer;

	public class SerializersFactory {
		public function getProjectSerializer():ProjectSerializer {
			return new ProjectSerializer();
		}
	}
}