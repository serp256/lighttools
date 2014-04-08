package ui.vbase {
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.text.engine.TextBaseline;
	import flash.utils.getDefinitionByName;
	import flashx.textLayout.elements.InlineGraphicElement;

	/**
	 * Менеджер скинов
	 */
	public class AssetManager {
		public static var url:String = '';
		public static const externDispatcher:EventDispatcher = new EventDispatcher();
		private static const swfCache:Object = { };

		/**
		 * Применить вложенный скин
		 * 
		 * @param	target				Объект VSkin, куда будет помещен скин
		 * @param	skinName			Имя вложенного скина
		 */
		public static function applyEmbedSkin(target:VSkin, skinName:String):void {
			try {
				var clsSkin:Class = getDefinitionByName('ESkins.' + skinName) as Class;
				var skin:Object = new clsSkin();
			} catch (error:ReferenceError) {
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
		public static function getEmbedSkin(skinName:String, mode:uint = 0):VSkin {
			var target:VSkin = new VSkin(mode);
			applyEmbedSkin(target, skinName);
			return target;
		}
		
		/**
		 * Применить внешний скин
		 * 
		 * @param	target				Объект VSkin, куда будет помещен скин
		 * @param	packName			Имя пакета
		 * @param	skinName			Имя внешнего скина (опционально, для картинки не юзается)
		 * @param	isImage				Грузим картинку
		 * @param	isPng				PNG, к имени пакету будет добавлено .png, если используются другие расширения то нужно прописывать в имени пакета
		 * @param	isUseLoadClip
		 */
		public static function applyExternSkin(target:VSkin, packName:String, skinName:String = null, isImage:Boolean = false, isPng:Boolean = true,
		isUseLoadClip:Boolean = true):void {
			if (!packName) {
				return;
			}
			
			if (isImage && isPng) {
				packName += '.png';
			}
			
			var data:Object = swfCache[packName];
			//скин загрузить не удалось || скин уже загружен
			if (data === false || data is Loader) {
				target.applyContent(getCopyExternSkin(packName, skinName));
			} else {
				target.setExternSkinInterest(new VOExternInfo(packName, skinName));
				
				if (data == null) { //скин еще не загружался
					var assetLoader:AssetLoader = new AssetLoader();
					swfCache[packName] = true;
					assetLoader.packName = packName;
					assetLoader.init(onExternLoadHandler);
					if (isImage) {
						var path:String = 'images/' + packName;
					} else {
						path = 'swfs/' + packName + '.swf';
					}
					assetLoader.loadUrl(url + path + '?v=119961', !isImage);
				}
				
				if (isUseLoadClip) {
					if (target.measuredWidth > 36 && target.measuredHeight > 36) {
						var skin:VSkin = getEmbedSkin('SkullClip', VSkin.CONTAIN | VSkin.NO_STOP_MOVIECLIP);
						skin.setLayout( { left:4, right:4, top:4, bottom:4 } );
						target.addWaitClip(skin);
					}
				}
			}
		}
		
		/**
		 * Аналог applyExternSkin для SWF, где аргумент name определяет packName и skinName
		 * 
		 * @param	target				Объект VSkin, куда будет помещен скин
		 * @param	name				Если в паке: "packName,skinName", иначе "packName"
		 * @param	isUseLoadClip
		 */
		public static function applyExternSkinFromName(target:VSkin, name:String, isUseLoadClip:Boolean = true):void {
			var i:int = name.indexOf(',');
			var isPack:Boolean = i >= 0;
			applyExternSkin(target,
				isPack ? name.substr(0, i) : name,
				isPack ? name.substr(i + 1) : null,
				false, false, isUseLoadClip
			);
		}
		
		/**
		 * Получить внешний скин
		 * 
		 * @param	packName				Имя пакета
		 * @param	skinName				Имя скина
		 * @param	mode					Режимы работы скина см описание констант в VSkin
		 * @param	isUseLoadClip			Добавлять в режим флаг VSkin.USE_LOAD_CLIP
		 * @return
		 */
		public static function getExternSkin(packName:String, skinName:String = null, mode:uint = 0, isUseLoadClip:Boolean = true):VSkin {
			var target:VSkin = new VSkin(mode);
			applyExternSkin(target, packName, skinName, false, true, isUseLoadClip);
			return target;
		}
		
		/**
		 * Получить png-картинку
		 * 
		 * @param	name					Имя картинки (если юзается не PNG, то добавлять расширение, для PNG обязательно без него)
		 * @param	mode					Режимы работы скина см описание констант в VSkin
		 * @param	isPng					PNG
		 * @return
		 */
		public static function getImage(name:String, mode:uint = 0, isPng:Boolean = true):VSkin {
			var target:VSkin = new VSkin(mode);
			applyExternSkin(target, name, null, true, isPng);
			return target;
		}
		
		/**
		 * Вставляет скин внутрь дочернего объекта контейнера
		 * 
		 * @param	container			Контейнер, в рамках которого будет поиск целевого объекта, в который будет произведена вставка
		 * @param	boxName				Имя целевого объекта
		 * @param	skin				Вставляемый скин
		 */
		public static function setBoxSkin(container:Sprite, boxName:String, skin:DisplayObject):void {
			for (var i:int = container.numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = container.getChildAt(i);
				if (obj.name == boxName) {
					if (obj is Sprite) {
						(obj as Sprite).addChild(skin);
					}
					break;
				}
			}
			
			if (skin is VBaseComponent) {
				(skin as VBaseComponent).geometryPhase();
			}
		}
		
		/**
		 * Копировать уже загруженный внешний скин
		 * 
		 * @param	packName	Имя пакета
		 * @param	skinName	Имя скина внутри пакета || null
		 * @return				BitmapData || DisplayObject || null
		 */
		public static function getCopyExternSkin(packName:String, skinName:String):Object {
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
		public static function onExternLoadHandler(assetLoader:AssetLoader):void {
			swfCache[assetLoader.packName] = assetLoader.isError ? false : assetLoader.loader;
			externDispatcher.dispatchEvent(new Event(assetLoader.packName));
		}
		
		//формат img@source: "(swf|lib|png|img),packName[,skinName][,'useBg']"
		public static function inlineGraphicResolverFunction(element:InlineGraphicElement):VBaseComponent {
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
			
			var component:VBaseComponent;
			if (len >= 2) {
				var packName:String = ar[1] as String;
				if (packName) {
					if (len >= 3) {
						var skinName:String = ar[2] as String;
						if (skinName == '') {
							skinName = null;
						}
					}
					
					var t:String = ar[0] as String;
					switch (t) {
						case 'lib':
							component = getEmbedSkin(packName);
							break;
							
						case 'swf':
							component = getExternSkin(packName, skinName);
							break;
							
						case 'png':
							component = getImage(packName);
							break;
							
						case 'img':
							component = getImage(packName, 0, false);
							break;

						case 'avatar':
							break;
					}
				}
			}

			if (!component) {
				var skin:VSkin = new VSkin();
				component = skin;
			} else {
				skin = component as VSkin;
			}

			if (skin) {
				var mode:uint = skin.isContent ? VSkin.LEFT : 0;
				if (len >= 4) {
					var useBg:Boolean = ar[3] == 'useBg';
				}
				if (Boolean(useBg)) {
					mode = (mode == 0) ? VSkin.USE_BG : mode | VSkin.USE_BG;
				}
				
				skin.setMode(mode, false);
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
		 * @param	isExtern		true - внешний скин, false - embed
		 * @param	packName		Имя пакета
		 * @param	isImage			true - image, false - swf
		 * @param	skinName		Имя скина внутри пакета || null
		 * @param	isPng			PNG, к имени пакету будет добавлено .png, если используются другие расширения то нужно прописывать в имени пакета
		 * @return
		 */
		public static function getTLFSource(isExtern:Boolean, packName:String, isImage:Boolean = false, skinName:String = null, isPng:Boolean = true):String {
			if (isExtern) {
				if (skinName) {
					packName += ',' + skinName;
				}
				if (isImage) {
					return (isPng ? 'png,' : 'img,') + packName;
				} else {
					return 'swf,' + packName;
				}
			}
			return 'lib,' + packName;
		}
		
	} //end class
} //end package
