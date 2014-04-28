package ui.vbase {
	import flash.display.Sprite;
	import flash.filters.GlowFilter;
	import flash.geom.Rectangle;
	import flashx.textLayout.compose.IFlowComposer;
	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.container.ScrollPolicy;
	import flashx.textLayout.conversion.ConversionType;
	import flashx.textLayout.conversion.TextConverter;
	import flashx.textLayout.conversion.TextLayoutImporter;
	import flashx.textLayout.elements.*;
	import flashx.textLayout.formats.LeadingModel;
	import flashx.textLayout.formats.LineBreak;
	import flashx.textLayout.formats.TextAlign;
	import flashx.textLayout.formats.VerticalAlign;
	import flashx.textLayout.tlf_internal;
	
	public class VLabel extends VBaseComponent {
		public static const
			VERTICAL_MIDDLE:uint = 1, //размещение по вертикальному центру
			CONTAIN:uint = 2, //режим вписывания
			VERTICAL_BOTTOM:uint = 4,
			LEADING_BOX:uint = 8,
			CENTER:uint = 16,
			W_100:uint = 32, //задает компоновку w:'100%'
			IMG_HINT:uint = 72; //72 = 64 | 8, может использоваться подсказка на картинках
			
		protected static const importer:TextLayoutImporter = new TextLayoutImporter();
		
		protected var textFlow:TextFlow;
		protected var mode:uint;
		//попытки использования в качестве контайнера под текст самого компонента приводят к тому, что при очистке
		//ширина и высота остаются равными старому размеру (должны 0,0),
		//и при следующем добавлении текста он начинает вести себя местами неадекватно
		protected var content:Sprite;
		
		public function VLabel(text:String = null, mode:uint = 0):void {
			mouseEnabled = false;
			mouseChildren = (mode & IMG_HINT) != 0;
			this.mode = mode;
			this.text = text;

			if (mode & W_100) {
				layout.w = 100;
				layout.isWPercent = true;
			}
		}
		
		public function set text(value:String):void {
			if (textFlow) {
				clearText();
				textFlow = null;
			}
			
			if (value != null && value.length > 0) {
				try {
					textFlow = importer.createTextFlowFromXML(
						new XML('<TextFlow xmlns="http://ns.adobe.com/textLayout/2008" version="3.0.0">' + value + '</TextFlow>')
					);
					if (mode & LEADING_BOX) {
						textFlow.leadingModel = LeadingModel.BOX;
					}
					if (mode & CONTAIN) {
						textFlow.lineBreak = LineBreak.EXPLICIT;
					}
					if (mode & CENTER) {
						textFlow.textAlign = TextAlign.CENTER;
					}
					
					if (mode & VERTICAL_MIDDLE) {
						textFlow.verticalAlign = VerticalAlign.MIDDLE;
					} else if (mode & VERTICAL_BOTTOM) {
						textFlow.verticalAlign = VerticalAlign.BOTTOM;
					}
				} catch (error:Error) {
					trace('Не собрался TextFlow:', value);
				}
			}
			
			syncContentSize(true);
		}
		
		public function get text():String {
			return textFlow ? textFlow.getText() : null;
		}
		
		/**
		 * Режим
		 * 
		 * @return
		 */
		public function getMode():uint {
			return mode;
		}
		
		public function setMode(value:uint):void {
			mode = value;
			text = tlfText;
		}
		
		public function get tlfText():String {
			if (textFlow) {
				var str:String = TextConverter.export(textFlow, TextConverter.TEXT_LAYOUT_FORMAT, ConversionType.STRING_TYPE) as String;
				if (str && str.substr(0, 9) == '<TextFlow') { //срежим обрамляющий TextFlow
					var i:int = str.indexOf('>');
					if (i > 0) {
						//</TextFlow> len == 11
						str = str.slice(i + 1, -11);
					}
				}
			}
			return str;
		}
		
		override public function dispose():void {
			clearText();
			super.dispose();
		}
		
		protected function clearText():void {
			if (textFlow) {
				textFlow.flowComposer.removeAllControllers();
			}
			if (content) {
				removeChild(content);
				content = null;
			}
		}
		
		protected function buildText(compositionWidth:Number, compositionHeight:Number):void {
			clearText();
			
			content = new Sprite();
			addChild(content);
			var composer:IFlowComposer = textFlow.flowComposer;
			var cc:ContainerController = new ContainerController(content, compositionWidth, compositionHeight);
			cc.verticalScrollPolicy = ScrollPolicy.OFF;
			composer.addController(cc);
			composer.updateAllControllers();
		}
		
		override protected function calcContentSize():void {
			if (textFlow) {
				if (textFlow.flowComposer.numControllers == 0) {
					//если задана точная ширина и высота, то она считается размером содержимого
					if (layout.w > 0) {
						if (!layout.isWPercent) {
							var w:uint = layout.applyRangeW(layout.w);
						} else if (parent is VBaseComponent) {
							var p_layout:VLayout = (parent as VBaseComponent).getLayout();
							if (p_layout.w > 0 && !p_layout.isWPercent) {
								w = layout.applyRangeW(p_layout.w * (layout.w / 100));
							}
						}
					}
					if (w == 0 && layout.maxW > 0) {
						w = layout.maxW;
					}
					if (layout.h > 0 && !layout.isHPercent) {
						var h:uint = layout.applyRangeH(layout.h);
					}
					buildText(w > 0 ? w : NaN, h > 0 ? h : NaN);
				}
				
				var cc:ContainerController = textFlow.flowComposer.getControllerAt(0);
				
				contentW = Math.ceil(cc.tlf_internal::contentWidth);
				updateW = (w > contentW) ? w : contentW;
				if (mode & LEADING_BOX) {
					var rect:Rectangle = content.getRect(null);
					contentH = Math.ceil(rect.height + rect.y);
				} else {
					contentH = Math.ceil(cc.tlf_internal::contentHeight);
				}
				updateH = (h > contentH) ? h : contentH;
			}
		}
		
		override protected function customUpdate():void {
			if (textFlow) {
				buildText(w, h);
				
				//вписывание
				if (mode & CONTAIN) {
					var cc:ContainerController = textFlow.flowComposer.getControllerAt(0);
					var textW:uint = Math.ceil(cc.tlf_internal::contentWidth);
					
					if (textW > w) {
						buildText(textW, h);
						
						var y:Number = cc.tlf_internal::contentTop;
						var textH:Number = content.height;
						VLayout.applySize(content, w, h, true);
						
						//идет вписывание в ширину и content.x остается на месте
						//строки выравниваются по dominantBaseline, поэтому требуется коррекция y
						content.y = Math.ceil(y * (1 - content.scaleY) + (textH - content.height) / 2);
					}
				}
			}
		}
		
		public function setGlowFilter(color:uint, blur:uint, strength:Number):void {
			filters = [new GlowFilter(color, 1, blur, blur, strength)];
		}
		
		override public function add(component:VBaseComponent, layout:Object = null, index:int = -1):void {
			throw new Error('VLabel no use add method');
		}
		
		override public function remove(component:VBaseComponent, isDispose:Boolean = true):void {
			throw new Error('VLabel no use remove method');
		}
		
	} //end class
}