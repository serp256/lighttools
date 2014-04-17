package ui.vbase {
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Graphics;
	import flash.display.MovieClip;
	import flash.display.PixelSnapping;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	
	public class VSkin extends VBaseComponent {
		public static const NO_STRETCH:uint = 0x1;
		/**
		 * Вписывать в размер контейнера с учетом пропорции, но не больше масштаба 1
		 */
		public static const CONTAIN:uint = 0x2;
		/**
		 * Растягивать в размер контейнера без учета пропорций
		 */
		public static const STRETCH:uint = 0x4;
		public static const USE_BG:uint = 0x8; //использовать прозрачную подложку (применяется в TextFlow)
		public static const USE_SPLIT_SCALE:uint = 0x10; //использовать разбиение на битмапы при масштабировании
		public static const ZERO_CENTER:uint = 0x20; //центр контента находится в точке 0,0
		public static const CACHE_AS_BITMAP:uint = 0x40; //задать в true флаг cacheAsBitmap
		public static const NO_SMOOTHING:uint = 0x80; //в случае bitmapData не исопльзовать сглаживание
		public static const NO_STOP_MOVIECLIP:uint = 0x100; //не останавливать movieclip (если задан USE_SPLIT_SCALE, то не применяется)
		public static const ROTATE_90:uint = 0x200; //повороты скина
		public static const ROTATE_180:uint = 0x400;
		public static const ROTATE_270:uint = 0x800;
		public static const FLIP_X:uint = 0x1000;
		public static const FLIP_Y:uint = 0x2000;
		//TOP, LEFT, RIGHT, BOTTOM, LEFT_TOP работают если не задан ZERO_CENTER, определяют внутреннее расопложение содержимого, если не заданы то по центру
		public static const TOP:uint = 0x4000; //отменяет центрирование контена (не работает с ZERO_CENTER)
		public static const LEFT:uint = 0x8000;
		public static const RIGHT:uint = 0x10000;
		public static const BOTTOM:uint = 0x20000;
		public static const LEFT_TOP:uint = 0xC000; //LEFT || TOP
		/**
		 * Генерить событие завершения загрузки внешнего скина
		 */
		public static const EXTERN_COMPLETE_EVENT:uint = 0x40000;
		/**
		 * Использовать пользовательский размер содержимого
		 * Передавать этот режим напрямую в конструктор, если размер содержимого нужен 0,0
		 * Иначе юзать метод useCustomContentSize
		 */
		public static const CUSTOM_CONTENT_SIZE:uint = 0x80000;
		/**
		 * Компонент может содержать другие VBaseComponent
		 */
		public static const BOX:uint = 0x100000;

		private var view:DisplayObject; //указатель на содержимое || клип ожидания
		private var externInfo:VOExternInfo; //параметры внешнего скина во время загрузки
		private var mode:uint;
		private var $isContent:Boolean;
		
		/**
		 * Скин
		 * 
		 * @param	mode			Режим
		 */
		public function VSkin(mode:uint = 0):void {
			this.mode = mode;
			mouseEnabled = mouseChildren = false;
		}
		
		public function addWaitClip(component:VBaseComponent):void {
			if (!isContent) {
				clearContent();
				view = component;
				addChild(view);
				if (isGeometryPhase) {
					component.geometryPhase();
				}
			}
		}
		
		public function getMode():uint {
			return mode;
		}

		/**
		 * Изменить режим
		 *
		 * @param value          Новое значение
		 * @param isSync         false - только если в дальнейшем сразу будет обновление компонента
		 */
		public function setMode(value:uint, isSync:Boolean = true):void {
			mode = value;
			if (isSync) {
				syncContentSize(false);
			}
		}
		
		public function get content():DisplayObject {
			return $isContent ? view : null;
		}
		
		public function get isContent():Boolean {
			return $isContent;
		}
		
		override public function get contentWidth():uint {
			return ($isContent || (mode & CUSTOM_CONTENT_SIZE) != 0) ? contentW : 10;
		}
		
		override public function get contentHeight():uint {
			return ($isContent || (mode & CUSTOM_CONTENT_SIZE) != 0) ? contentH : 10;
		}
		
		/**
		 * Сбросить содержимое скина
		 * Применяется при многократной изменении контента
		 */
		public function resetContent():void {
			//сбросим возможную заинтересованность во внешнем скине
			setExternSkinInterest();
			//удалим содержимое
			clearContent();
		}
		
		/**
		 * Очистить содержимое скина
		 */
		protected function clearContent():void {
			$isContent = false;
			if (view) {
				removeChild(view);
				if (view is VBaseComponent) {
					(view as VBaseComponent).dispose();
				} else if (view is DisplayObjectContainer) {
					controlMovieClipPlay(view as DisplayObjectContainer, false);
				}
				view = null;
			}
		}
		
		override public function dispose():void {
			setExternSkinInterest();
			if (view is DisplayObjectContainer) {
				controlMovieClipPlay(view as DisplayObjectContainer, false);
			}
			super.dispose();
		}
		
		/**
		 * Задает заинтересованность во внешнем скине
		 * Внешне вызывается только из AssetManager
		 * 
		 * @param	newSkinName			Имя внешнего скина || null - скинуть интерес
		 */
		public function setExternSkinInterest(newExternInfo:VOExternInfo = null):void {
			if (externInfo) {
				AssetManager.externDispatcher.removeEventListener(externInfo.packName, onExternSkinHandler);
				externInfo = null;
			}
			
			if (newExternInfo) {
				clearContent(); //удалим содержимое
				externInfo = newExternInfo;
				AssetManager.externDispatcher.addEventListener(externInfo.packName, onExternSkinHandler);
			}
		}
		
		private function onExternSkinHandler(event:Event):void {
			if (externInfo) {
				applyContent(AssetManager.getCopyExternSkin(externInfo.packName, externInfo.skinName));
				
				if (mode & EXTERN_COMPLETE_EVENT) {
					dispatchEvent(new VEvent(VEvent.EXTERN_COMPLETE, externInfo));
				}
			}
		}
		
		public function applyContent(content:Object):void {
			setExternSkinInterest();
			clearContent();
			$isContent = true;
			
			if (content) {
				var isCache:Boolean = true; //не кешируются производные от MovieClip, ScaleSkin, Bitmap
				if (content is BitmapData) {
					content = new Bitmap(content as BitmapData, PixelSnapping.AUTO, (mode & NO_SMOOTHING) == 0);
					isCache = false;
				} else if (content is MovieClip) {
					if (!(mode & NO_STOP_MOVIECLIP) || (mode & USE_SPLIT_SCALE)) {
						controlMovieClipPlay(content as MovieClip, false);
					}
					isCache = false;
				}
				if ((mode & USE_SPLIT_SCALE) && content.scale9Grid != null) {
					content = new ScaleSkin(content as DisplayObject);
					isCache = false;
				}
				if (isCache && (mode & CACHE_AS_BITMAP)) {
					(content as DisplayObject).cacheAsBitmap = true;
				}
			} else {
				content = getDefaultContent();
			}
			
			view = addChildAt(content as DisplayObject, 0);
			
			if ((mode & CUSTOM_CONTENT_SIZE) == 0) {
				updateContentSize();
			}
			syncContentSize(false);
		}
		
		private function getDefaultContent():Shape {
			var shape:Shape = new Shape();
			
			var g:Graphics = shape.graphics;
			g.beginFill(0xFF0000);
			g.drawRect(0, 0, 100, 100);
			g.beginFill(0xFFFFFF);
			g.drawRect(1, 1, 98, 98);
			g.beginFill(0xFF0000);
			
			g.drawRect(0, 0, 5, 5);
			g.drawRect(95, 0, 5, 5);
			g.drawRect(0, 95, 5, 5);
			g.drawRect(95, 95, 5, 5);
			
			g.lineStyle(1, 0xFF0000);
			g.moveTo(5, 5);
			g.lineTo(95, 95);
			g.moveTo(95, 5);
			g.lineTo(5, 95);
			
			shape.scale9Grid = new Rectangle(6, 6, 88, 88);
			return shape;
		}
		
		private function updateContentSize():void {
			if ($isContent) {
				var isReverse:Boolean = (mode & ROTATE_90) != 0 || (mode & ROTATE_270) != 0;
				contentW = Math.ceil(isReverse ? view.height : view.width);
				contentH = Math.ceil(isReverse ? view.width : view.height);
			}
		}
		
		/**
		 * Использовать пользовательский размер содержимого
		 * 
		 * @param	w			ширина
		 * @param	h			высота
		 */
		public function useCustomContentSize(w:uint = 0, h:uint = 0):void {
			mode |= CUSTOM_CONTENT_SIZE;
			contentW = w;
			contentH = h;
			syncContentSize(false);
		}
		
		/**
		 * Использовать размер содержимого
		 * Имеет смысл вызывать если ранее вызывался метод useCustomContentSize
		 */
		public function useSkinContentSize():void {
			mode &= ~CUSTOM_CONTENT_SIZE;
			updateContentSize();
			syncContentSize(false);
		}
		
		override protected function customUpdate():void {
			if (mode & BOX) {
				updateAllChild();
			}

			if (mode & USE_BG) {
				graphics.clear();
				graphics.beginFill(0, 0);
				graphics.drawRect(0, 0, w, h);
			}
			if (!view) {
				return;
			}
			if ($isContent) {
				view.transform.matrix = new Matrix();
				var reverse:Boolean = (mode & ROTATE_90) != 0 || (mode & ROTATE_270) != 0;
				if (reverse) {
					var wm:uint = h;
					var hm:uint = w;
				} else {
					wm = w;
					hm = h;
				}
				
				if ((mode & NO_STRETCH) == 0) {
					if (mode & STRETCH) {
						view.width = wm;
						view.height = hm;
					} else {
						VLayout.applySize(view, wm, hm, (mode & CONTAIN) != 0);
					}
				}
				
				var dx:Number = 0;
				var dy:Number = 0;
				//поворот
				if (mode & ROTATE_90) {
					view.rotation = 90;
					dx = view.width;
				} else if (mode & ROTATE_180) {
					view.rotation = 180;
					dx = view.width;
					dy = view.height;
				} else if (mode & ROTATE_270) {
					view.rotation = 270;
					dy = view.height;
				}
				
				//флип
				var flipX:Boolean;
				var flipY:Boolean;
				if (mode & FLIP_X) {
					if (reverse) {
						flipY = true;
					} else {
						flipX = true;
					}
					dx = (dx == 0) ? view.width : 0;
				}
				if (mode & FLIP_Y) {
					if (reverse) {
						flipX = true;
					} else {
						flipY = true;
					}
					dy = (dy == 0) ? view.height : 0;
				}
				if (flipX) {
					view.scaleX *= -1;
				}
				if (flipY) {
					view.scaleY *= -1;
				}
				
				//позиция
				if (mode & ZERO_CENTER) {
					view.x = wm >> 1;
					view.y = hm >> 1;
					//view.x = wm / 2;
					//view.y = hm / 2;
				} else {
					/*
					if ((mode & LEFT_TOP) == 0) {
						dx += (w - view.width) / 2;
						dy += (h - view.height) / 2;
					}
					*/
					if (mode & RIGHT) {
						dx += w - view.width;
					} else if ((mode & LEFT) == 0) {
						dx += (w - view.width) / 2;
					}
					if (mode & BOTTOM) {
						dy += h - view.height;
					} else if ((mode & TOP) == 0) {
						dy += (h - view.height) / 2;
					}
					
					view.x = dx;
					view.y = dy;
				}
			} else {
				if (view is VBaseComponent) {
					(view as VBaseComponent).geometryPhase();
				}
			}
		}
		
		public function contentPlay(value:Boolean):void {
			if ($isContent) { //если содержимое есть
				if (view is DisplayObjectContainer) {
					controlMovieClipPlay(view as DisplayObjectContainer, value);
				}
			} else { //если нету, то вызов метода будет менять флаг NO_STOP_MOVIECLIP
				if (value) {
					mode |= NO_STOP_MOVIECLIP;
				} else {
					mode &= ~NO_STOP_MOVIECLIP;
				}
			}
		}
		
		/**
		 * запустить/остановить мувик и всех его потомков
		 * @param	container
		 * @param	value
		 */
		public static function controlMovieClipPlay(container:DisplayObjectContainer, value:Boolean):void {
			if (container is MovieClip) {
				var mc:MovieClip = container as MovieClip;
				if (value) {
					mc.play();
				} else if (mc.totalFrames > 1) {
					mc.gotoAndStop(0);
				}
			}
			for (var i:int = container.numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = container.getChildAt(i);
				if (obj is DisplayObjectContainer) {
					controlMovieClipPlay(obj as DisplayObjectContainer, value);
				}
			}
		}
		
		override public function add(component:VBaseComponent, layout:Object = null, index:int = -1):void {
			if (mode & BOX) {
				super.add(component, layout);
			} else {
				throw new Error('VSkin no use add method');
			}
		}
		
		override public function remove(component:VBaseComponent, isDispose:Boolean = true):void {
			if (mode & BOX) {
				super.remove(component, isDispose);
			} else {
				throw new Error('VSkin no use remove method');
			}
		}
		
	} //end class
}