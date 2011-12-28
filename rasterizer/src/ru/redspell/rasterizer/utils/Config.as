package ru.redspell.rasterizer.utils {
	import flash.utils.Endian;

	public class Config {
		public static const DEFAULT_PACK_NAME:String = 'new pack';
		public static const DEFAULT_SWFS_DIR:String = 'swfs';
		public static const DEFAULT_OUT_DIR:String = 'out';
		public static const ENDIAN:String = Endian.BIG_ENDIAN;
		public static const PROJECT_FILE_EXT:String = '.rst';
		public static const STATUS_REFRESH_TIME:Number = 100;
		public static const DEFAULT_BEFORE_SAVE_STATUS:String = 'saving project...';
		public static const DEFAULT_AFTER_SAVE_STATUS:String = 'project saved';
	}
}