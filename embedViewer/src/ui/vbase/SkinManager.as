package ui.vbase {
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.text.engine.FontLookup;
	import flash.text.engine.TextBaseline;
	import flash.utils.getDefinitionByName;

	import flashx.textLayout.elements.Configuration;
	import flashx.textLayout.elements.InlineGraphicElement;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.formats.TextLayoutFormat;
	import flashx.textLayout.formats.WhiteSpaceCollapse;

	/**
	 * Менеджер скинов
	 */
	public class SkinManager {
		public static const
			LOAD_CLIP:uint = 1,
			NO_CACHE:uint = 2,
			PNG:uint = 4,
			JPG:uint = PNG | 8,
			externalDispatcher:EventDispatcher = new EventDispatcher()
			;
		private static const swfCache:Object = {};
		public static var
			url:String,
			randomKey:String = '189955'
			;

		public static function init(externalUrl:String):TextLayoutFormat {
			url = externalUrl;

			XML.ignoreProcessingInstructions = false;
			XML.ignoreWhitespace = false;

			var config:Configuration = TextFlow.defaultConfiguration;
			config.inlineGraphicResolverFunction = SkinManager.inlineGraphicResolverFunction;
			config.manageTabKey = false;

			var format:TextLayoutFormat = config.textFlowInitialFormat as TextLayoutFormat;
			format.fontLookup = FontLookup.EMBEDDED_CFF;
			//format.lineHeight = '120%';
			format.whiteSpaceCollapse = WhiteSpaceCollapse.PRESERVE;
			return format;
		}

		/**
		 * Применить вложенный скин
		 *
		 * @param	target				Объект VSkin, куда будет помещен скин
		 * @param	skinName			Имя вложенного скина
		 */
		public static function applyEmbed(target:VSkin, skinName:String):void {
			try {
				var clsSkin:Class = getDefinitionByName('eSkins.' + skinName) as Class;
				var skin:Object = new clsSkin();
			} catch (error:ReferenceError) {
				try {
					clsSkin = getDefinitionByName('ESkins.' + skinName) as Class;
					skin = new clsSkin();
				} catch (error:ReferenceError) {
					trace('applyEmbed', error);
				}
			}
			target.applyContent(skin);
		}

		/**
		 * Получить встроенный скин
		 *
		 * @param	skinName			Имя скина
		 * @param	mode				Режимы работы скина см описание констант в VSkin
		 * @return
		 */
		public static function getEmbed(skinName:String, mode:uint = 0):VSkin {
			var target:VSkin = new VSkin(mode);
			applyEmbed(target, skinName);
			return target;
		}

		/**
		 * Применить внешний скин
		 *
		 * @param	target				Объект VSkin, куда будет помещен скин
		 * @param	packName			Имя пакета
		 * @param	skinName			Имя внешнего скина (опционально, для картинки не юзается)
		 * @param	externalMode		Режимы загрузки внешних скинов
		 */
		public static function applyExternal(target:VSkin, packName:String, skinName:String = null, externalMode:uint = 0):void {
			CONFIG::debug {
				if (!packName) {
					throw new Error();
				}
			}

			var isImage:Boolean = (externalMode & PNG) != 0;
			if (isImage) {
				packName += (externalMode & JPG) == JPG ? '.jpg' : '.png';
			}

			var data:Object = swfCache[packName];
			//скин загрузить не удалось || скин уже загружен
			if (data === false || data is Loader) {
				target.applyContent(getCopyExternal(packName, skinName));
			} else {
				target.setExternalInterest(new VOExternalInfo(packName, skinName));

				if (data == null) { //скин еще не загружался
					var assetLoader:AssetLoader = new AssetLoader();
					if ((externalMode & NO_CACHE) == 0) {
						swfCache[packName] = true;
					}
					assetLoader.packName = packName;
					assetLoader.init(onExternalLoad);
					assetLoader.loadUrl(url + (isImage ? 'images/' + packName : 'swfs/' + packName + '.swf') + '?v=' + randomKey, !isImage);
				}

				if ((externalMode & LOAD_CLIP) != 0) {
					target.useLoadClip();
				}
			}
		}

		public static function loadSwf(packName:String):void {
			if (swfCache[packName] == null) {
				var assetLoader:AssetLoader = new AssetLoader();
				swfCache[packName] = true;
				assetLoader.packName = packName;
				assetLoader.init(onExternalLoad);
				assetLoader.loadUrl(url + 'swfs/' + packName + '.swf?v=' + randomKey, true);
			}
		}

		/**
		 * Получить внешний скин
		 *
		 * @param	skinName				Имя скина
		 * @param	externalMode			Режимы загрузки внешних скинов
		 * @param	skinMode				Режимы работы скина см описание констант в VSkin
		 * @return
		 */
		public static function getExternal(skinName:String, externalMode:uint = 0, skinMode:uint = 0):VSkin {
			var target:VSkin = new VSkin(skinMode);
			applyExternal(target, skinName, null, externalMode);
			return target;
		}

		/**
		 * Получить внешний пакетный скин
		 *
		 * @param	packName				Имя пакета
		 * @param	skinName				Имя скина
		 * @param	skinMode				Режимы работы скина см описание констант в VSkin
		 * @param	externalMode			Режимы загрузки внешних скинов
		 * @param	externalHandler			Будет вызван ТОЛЬКО если сейчас идет загрузка
		 * @return
		 */
		public static function getPack(packName:String, skinName:String, skinMode:uint = 0, externalMode:uint = 0, externalHandler:Function = null):VSkin {
			var target:VSkin = new VSkin(skinMode);
			applyExternal(target, packName, skinName, externalMode);
			if (externalHandler != null && !target.isContent) {
				target.setMode(target.getMode() | VSkin.EXTERNAL_EVENT, false);
				target.addEventListener(VEvent.EXTERNAL_COMPLETE, externalHandler);
			}
			return target;
		}

		/**
		 * Вставляет скин внутрь дочернего объекта контейнера
		 *
		 * @param	container			Контейнер, в рамках которого будет поиск целевого объекта, в который будет произведена вставка
		 * @param	boxName				Имя целевого объекта
		 * @param	skin				Вставляемый скин
		 */
		public static function addInsideContainer(container:Sprite, boxName:String, skin:DisplayObject):void {
			for (var i:int = container.numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = container.getChildAt(i);
				if (obj.name == boxName) {
					if (obj is Sprite) {
						(obj as Sprite).addChild(skin);
					}
					break;
				}
			}

			if (skin is VComponent) {
				(skin as VComponent).geometryPhase();
			}
		}

		/**
		 * Копировать уже загруженный внешний скин
		 *
		 * @param	packName	Имя пакета
		 * @param	skinName	Имя скина внутри пакета || null
		 * @return				BitmapData || DisplayObject || null
		 */
		public static function getCopyExternal(packName:String, skinName:String):Object {
			var loader:Loader = swfCache[packName] as Loader;
			if (loader) {
				try {
					if (loader.content is Bitmap) {
						return (loader.content as Bitmap).bitmapData;
					} else {
						var clsSkin:Class = loader.contentLoaderInfo.applicationDomain.getDefinition('Skins.' + (skinName ? skinName : packName)) as Class;
						return new clsSkin();
					}
				} catch (error:ReferenceError) {
				}
			}
			return null;
		}

		/**
		 * Обработчик завершения загрузки внешних графических ресурсов
		 *
		 * @param	assetLoader			Объект AssetLoader, который производил загрузку
		 */
		public static function onExternalLoad(assetLoader:AssetLoader):void {
			swfCache[assetLoader.packName] = assetLoader.isError ? false : assetLoader.loader;
			externalDispatcher.dispatchEvent(new Event(assetLoader.packName));
		}

		//формат img@source: "(swf|lib|png|img),packName[,skinName]"
		public static function inlineGraphicResolverFunction(element:InlineGraphicElement):VComponent {
			element.dominantBaseline = TextBaseline.IDEOGRAPHIC_CENTER;

			var src:String = element.source as String;

			if (element.width is uint) {
				var w:uint = element.width as uint;
			}
			if (element.height is uint) {
				var h:uint = element.height as uint;
			}

			var ar:Array = src.split(',');
			var len:uint = ar.length;

			var component:VComponent;
			if (len >= 2) {
				var packName:String = ar[1] as String;
				if (packName) {
					var t:String = ar[0] as String;
					if (t == 'lib') {
						component = getEmbed(packName);
					} else {
						component = getPack(packName, (len >= 3) ? ar[2] : null, 0, t == 'png' ? PNG : (t == 'jpg' ? JPG : 0));
					}
				}
			}

			var skin:VSkin;
			if (!component) {
				skin = new VSkin();
				component = skin;
			} else {
				skin = component as VSkin;
			}

			if (skin) {
				skin.setMode(skin.isContent ? VSkin.LEFT : 0, false);
				skin.setGeometrySize(w, h, true);

				//если скин загружен и если есть зазор справа то уберем его для более красивого прилегания текста к иконке
				if (skin.isContent && skin.width < w) {
					w = Math.ceil(skin.width);
					element.width = w;
				}

				skin.graphics.beginFill(0, 0);
				skin.graphics.drawRect(0, 0, w, h);
			} else {
				component.setGeometrySize(w, h, true);
			}

			if (element.locale) {
				component.hint = element.locale;
				component.mouseEnabled = true;
				element.locale = undefined;
			}

			return component;
		}

		/**
		 * Получить TLF-source
		 *
		 * @param	packName		Имя пакета
		 * @param	externalMode	Параметры внешнего скина || <0
		 * @param	skinName		Имя скина внутри пакета || null
		 * @return
		 */
		public static function getTLFSource(packName:String, externalMode:int = -1, skinName:String = null):String {
			if (externalMode >= 0) {
				if (skinName) {
					packName += ',' + skinName;
				}
				if ((externalMode & PNG) != 0) {
					return ((externalMode & JPG) == JPG ? 'jpg,' : 'png,') + packName;
				} else {
					return 'swf,' + packName;
				}
			}
			return 'lib,' + packName;
		}

	} //end class
}