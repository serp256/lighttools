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
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;

	public class VSkin extends VComponent {
		public static const
			NO_STRETCH:uint = 1,
			CONTAIN:uint = 2,				//Вписывать в размер контейнера с учетом пропорции, но не больше масштаба 1
			STRETCH:uint = 4,				//Растягивать в размер контейнера без учета пропорций
			DRAW_FILL:uint = 8,				//рисовать прозрачный векторный прямоугольник в размер содержимого
			SPLIT_SCALE:uint = 16,			//использовать разбиение на битмапы при масштабировании
			ZERO_CENTER:uint = 32,			//центр контента находится в точке 0,0
			CACHE_AS_BITMAP:uint = 64,		//задать в true флаг cacheAsBitmap
			NO_SMOOTHING:uint = 128,		//в случае bitmapData не исопльзовать сглаживание
			PLAY_MOVIE_CLIP:uint = 256,		//не останавливать movieClip (если задан USE_SPLIT_SCALE, то не применяется)
			ROTATE_90:uint = 512,			//повороты скина
			ROTATE_180:uint = 1024,
			ROTATE_270:uint = 2048,
			FLIP_X:uint = 4096,
			FLIP_Y:uint = 8192,
			//TOP, LEFT, RIGHT, BOTTOM, LEFT_TOP работают если не задан ZERO_CENTER, определяют внутреннее расопложение содержимого, если не заданы то по центру
			TOP:uint = 16384,				//отменяет центрирование контена (не работает с ZERO_CENTER)
			LEFT:uint = 32768,
			RIGHT:uint = 65536,
			BOTTOM:uint = 131072,
			EXTERNAL_EVENT:uint = 262144,	//Генерить событие завершения загрузки внешнего скина
			RANDOM_FRAME:uint = 524288,     //для MovieClip устанавливается произвольный кадр
			STRETCH_BG:uint = STRETCH | SKIP_CONTENT_SIZE
			;
		public static var
			defaultIconClass:Class,
			loadClipFactory:Function   //function ():VComponent
			;
		private var
			view:DisplayObject, //указатель на содержимое || клип ожидания
			externalInfo:VOExternalInfo, //параметры внешнего скина во время загрузки
			$isContent:Boolean
			;

/*
		public static const GREY_FILTER:ColorMatrixFilter = new ColorMatrixFilter([
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0, 0, 0, 1, 0
		]);
*/
		public static const GREY_FILTER:Array = [new ColorMatrixFilter([
			0.4077399957180023, 0.5484599471092224, 0.0737999975681305, 0, 10,
			0.2777400016784668,	0.6784599709510803, 0.0737999975681305, 0, 10,
			0.2777400016784668,	0.5484599471092224, 0.30379999160766602,0, 10,
			0,0,0,1,0
		])];
		//value = 162.56 (.28 * 127 + 127), brightness = .5 * (127 - value), value = value / 127
		//для консрастности 22 берется .28 (см таблицу AdjustColor.s_arrayOfDeltaIndex)
		//value = 1.28, brightness = -17.78
		//value подставляется в [0][0], [1][1], [2][2]
		//brightness подставляется в [0][4], [1][4], [2][4]
		public static const CONTRAST_FILTER:Array = [new ColorMatrixFilter([
			1.28, 0, 0, 0, -17.78,
			0, 1.28, 0, 0, -17.78,
			0, 0, 1.28, 0, -17.78,
			0, 0, 0, 1, 0
		])];

		/**
		 * Скин
		 * 
		 * @param	mode			Режим
		 */
		public function VSkin(mode:uint = 0) {
			this.mode = mode;
			mouseEnabled = mouseChildren = false;
		}
		
		public function useLoadClip():void {
			if (!isContent) {
				clearContent();
				if (loadClipFactory != null) {
					var component:VComponent = loadClipFactory();
					if (component) {
						view = component;
						addChild(view);
						if (isGeometryPhase) {
							component.geometryPhase();
						}
					}
				}
			}
		}

		public function useCustomLoadClip(clip:VComponent):void {
			if (!isContent) {
				clearContent();
				view = clip;
			}
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

		override public function get measuredWidth():uint {
			if (layoutW > 0) {
				return applyRangeW(layoutW);
			}
			if ($isContent) {
				if ((mode & NO_STRETCH) == 0 && (mode & STRETCH) == 0) {
					var v:uint = calcAccurateW();
					if (v > 0) {
						return v;
					}
					v = calcAccurateH();
					if (v > 0 && contentH > 0) {
						return applyRangeW(contentW * (v / contentH));
					}
				}
			}
			return applyRangeW(contentW);
		}

		override public function get measuredHeight():uint {
			if (layoutH > 0) {
				return applyRangeH(layoutH);
			}
			if ($isContent) {
				if ((mode & NO_STRETCH) == 0 && (mode & STRETCH) == 0) {
					var v:uint = calcAccurateH();
					if (v > 0) {
						return v;
					}
					v = calcAccurateW();
					if (v > 0 && contentW > 0) {
						return applyRangeH(contentH * (v / contentW));
					}
				}
			}
			return applyRangeH(contentH);
		}
		
		/**
		 * Сбросить содержимое скина
		 * Применяется при многократной изменении контента
		 */
		public function resetContent():void {
			//сбросим возможную заинтересованность во внешнем скине
			setExternalInterest();
			//удалим содержимое
			clearContent();
			contentW = contentH = 0;
		}
		
		/**
		 * Очистить содержимое скина
		 */
		protected function clearContent():void {
			$isContent = false;
			if (view) {
				view.parent.removeChild(view); //метод useCustomLoadClip позволяет задать компонент с произвольным родителем
				if (view is VComponent) {
					(view as VComponent).dispose();
				} else if (view is DisplayObjectContainer) {
					controlMovieClipPlay(view as DisplayObjectContainer, false);
				}
				view = null;
			}
		}
		
		override public function dispose():void {
			setExternalInterest();
			if (view is DisplayObjectContainer) {
				controlMovieClipPlay(view as DisplayObjectContainer, false);
			}
			super.dispose();
		}
		
		/**
		 * Задает заинтересованность во внешнем скине
		 * Внешне вызывается только из AssetManager
		 * 
		 * @param	newExternalInfo			Параметры внешнего скина || null - скинуть интерес
		 */
		public function setExternalInterest(newExternalInfo:VOExternalInfo = null):void {
			if (externalInfo) {
				SkinManager.externalDispatcher.removeEventListener(externalInfo.packName, onExternal);
				externalInfo = null;
			}
			
			if (newExternalInfo) {
				clearContent(); //удалим содержимое
				externalInfo = newExternalInfo;
				SkinManager.externalDispatcher.addEventListener(externalInfo.packName, onExternal);
			}
		}
		
		private function onExternal(event:Event):void {
			if (externalInfo) {
				applyContent(SkinManager.getCopyExternal(externalInfo.packName, externalInfo.skinName));
				
				if ((mode & EXTERNAL_EVENT) != 0) {
					dispatchEvent(new VEvent(VEvent.EXTERNAL_COMPLETE, externalInfo));
				}
			}
		}
		
		public function applyContent(content:Object):void {
			setExternalInterest();
			clearContent();
			$isContent = true;
			
			if (content) {
				var isCache:Boolean = true; //не кешируются производные от MovieClip, ScaleSkin, Bitmap
				if (content is BitmapData) {
					content = new Bitmap(content as BitmapData, PixelSnapping.AUTO, (mode & NO_SMOOTHING) == 0);
					isCache = false;
				} else if (content is MovieClip) {
					if ((mode & RANDOM_FRAME) != 0) {
						useRandomFrame(content as MovieClip);
					}
					if ((mode & PLAY_MOVIE_CLIP) == 0 || (mode & SPLIT_SCALE) != 0) {
						controlMovieClipPlay(content as MovieClip, false);
					}
					isCache = false;
				}
				if ((mode & SPLIT_SCALE) != 0 && content.scale9Grid != null) {
					content = new ScaleSkin(content as DisplayObject);
					isCache = false;
				}
				if (isCache && (mode & CACHE_AS_BITMAP) != 0) {
					(content as DisplayObject).cacheAsBitmap = true;
				}
			} else {
				if (defaultIconClass != null) {
					content = new defaultIconClass();
				} else {
					content = getDefaultContent();
				}
			}
			
			view = addChildAt(content as DisplayObject, 0);
			
			var isReverse:Boolean = (mode & ROTATE_90) != 0 || (mode & ROTATE_270) != 0;
			contentW = Math.ceil(isReverse ? view.height : view.width);
			contentH = Math.ceil(isReverse ? view.width : view.height);
			syncContentSize(false);
		}

		private function useRandomFrame(mc:MovieClip):void {
			if (mc.totalFrames > 1) {
				mc.gotoAndPlay(Math.round(Math.random() * mc.totalFrames));
			}
		}

		private function getDefaultContent():Shape {
			var shape:Shape = new Shape();
			
			var g:Graphics = shape.graphics;
			g.beginFill(0xFF0000);
			g.drawRect(0, 0, 50, 50);
			g.beginFill(0xFFFFFF);
			g.drawRect(1, 1, 48, 48);
			g.beginFill(0xFF0000);
			
			g.drawRect(0, 0, 2, 2);
			g.drawRect(48, 0, 2, 2);
			g.drawRect(0, 48, 2, 2);
			g.drawRect(48, 48, 2, 2);
			
			g.lineStyle(1, 0xFF0000);
			g.moveTo(2, 2);
			g.lineTo(48, 48);
			g.moveTo(48, 2);
			g.lineTo(2, 48);
			
			//shape.scale9Grid = new Rectangle(3, 3, 47, 47);
			return shape;
		}
		
		override protected function customUpdate():void {
			if ((mode & DRAW_FILL) != 0) {
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
					if ((mode & STRETCH) != 0) {
						view.width = wm;
						view.height = hm;
					} else {
						contain(view, wm, hm, (mode & CONTAIN) != 0);
					}
				}
				
				var dx:Number = 0;
				var dy:Number = 0;
				//поворот
				if ((mode & ROTATE_90) != 0) {
					view.rotation = 90;
					dx = view.width;
				} else if ((mode & ROTATE_180) != 0) {
					view.rotation = 180;
					dx = view.width;
					dy = view.height;
				} else if ((mode & ROTATE_270) != 0) {
					view.rotation = 270;
					dy = view.height;
				}
				
				//флип
				var flipX:Boolean;
				var flipY:Boolean;
				if ((mode & FLIP_X) != 0) {
					if (reverse) {
						flipY = true;
					} else {
						flipX = true;
					}
					dx = (dx == 0) ? view.width : 0;
				}
				if ((mode & FLIP_Y) != 0) {
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
				if ((mode & ZERO_CENTER) != 0) {
					view.x = wm >> 1;
					view.y = hm >> 1;
				} else {
					/*
					if ((mode & LEFT_TOP) == 0) {
						dx += (w - view.width) / 2;
						dy += (h - view.height) / 2;
					}
					*/
					if ((mode & RIGHT) != 0) {
						dx += w - view.width;
					} else if ((mode & LEFT) == 0) {
						dx += (w - view.width) / 2;
					}
					if ((mode & BOTTOM) != 0) {
						dy += h - view.height;
					} else if ((mode & TOP) == 0) {
						dy += (h - view.height) / 2;
					}
					
					view.x = dx;
					view.y = dy;
				}
			} else {
				if (view is VComponent) {
					(view as VComponent).geometryPhase();
				}
			}
		}

		/**
		 * Управление воспроизведение MovieClip
		 * @param  value     true - запустить воспроизведение, false - остановить
		 * @param  isPause   true - запуск и остановка не смещает текущий кадр
		 */
		public function contentPlay(value:Boolean, isPause:Boolean = false):void {
			if ($isContent) { //если содержимое есть
				if (view is DisplayObjectContainer) {
					if (value && !isPause && (mode & RANDOM_FRAME) != 0 && view is MovieClip) {
						useRandomFrame(view as MovieClip);
					}
					controlMovieClipPlay(view as DisplayObjectContainer, value, isPause);
				}
			} else { //если нету, то вызов метода будет менять флаг PLAY_MOVIE_CLIP
				if (value) {
					mode |= PLAY_MOVIE_CLIP;
				} else {
					mode &= ~PLAY_MOVIE_CLIP;
				}
			}
		}
		
		/**
		 * запустить/остановить мувик и всех его потомков
		 * @param	container
		 * @param	value
		 */
		public static function controlMovieClipPlay(container:DisplayObjectContainer, value:Boolean, isPause:Boolean = false):void {
			if (container is MovieClip) {
				var mc:MovieClip = container as MovieClip;
				if (value) {
					mc.play();
				} else if (mc.totalFrames > 1) {
					if (isPause) {
						mc.stop();
					} else {
						mc.gotoAndStop(0);
					}
				}
			}
			for (var i:int = container.numChildren - 1; i >= 0; i--) {
				var obj:DisplayObject = container.getChildAt(i);
				if (obj is DisplayObjectContainer) {
					controlMovieClipPlay(obj as DisplayObjectContainer, value, isPause);
				}
			}
		}

		public static function center(component:DisplayObject, target:Object):void {
			if (target is DisplayObject) {
				target = new Rectangle(target.x, target.y, target.width, target.height);
			}
			var rect:Rectangle = target as Rectangle;
			if (rect) {
				component.x = Math.round(rect.x + (rect.width - component.width) / 2);
				component.y = Math.round(rect.y + (rect.height - component.height) / 2);
			}
		}

		/**
		 * Вписать объект в размер с учетом его пропорции
		 *
		 * @param	obj				Целевой объект
		 * @param	w				Ширина вписывания
		 * @param	h				Высота
		 * @param	noIncrease		Не растягивать объект большe масштаба 1
		 */
		public static function contain(obj:DisplayObject, w:Number, h:Number, noIncrease:Boolean = false):void {
			if (noIncrease && obj.width <= w && obj.height <= h) {
				return;
			}
			if (w / h <= obj.width / obj.height) {
				obj.width = w;
				obj.scaleY = obj.scaleX;
			} else {
				obj.height = h;
				obj.scaleX = obj.scaleY;
			}
		}

		public static function outside(obj:DisplayObject, w:Number, h:Number):void {
			if (w / h <= obj.width / obj.height) {
				obj.height = h;
				obj.scaleX = obj.scaleY;
			} else {
				obj.width = w;
				obj.scaleY = obj.scaleX;
			}
		}

		CONFIG::debug
		override public function getToolPropList(out:Array):void {
			out.push(
				new VOComponentItem('stretch', VOComponentItem.CHECKBOX, null, (mode & VSkin.STRETCH) != 0, VSkin.STRETCH),
				new VOComponentItem('contain', VOComponentItem.CHECKBOX, null, (mode & VSkin.CONTAIN) != 0, VSkin.CONTAIN),
				new VOComponentItem('no_stretch', VOComponentItem.CHECKBOX, null, (mode & VSkin.NO_STRETCH) != 0, VSkin.NO_STRETCH),
				new VOComponentItem('left', VOComponentItem.CHECKBOX, null, (mode & VSkin.LEFT) != 0, VSkin.LEFT),
				new VOComponentItem('top', VOComponentItem.CHECKBOX, null, (mode & VSkin.TOP) != 0, VSkin.TOP)
			);
		}

		CONFIG::debug
		override public function updateToolProp(item:VOComponentItem):void {
			if (item.checkbox) {
				mode |= item.bit;
			} else {
				mode &= ~item.bit;
			}
			setMode(mode);
		}

	} //end class
}