package ui.vbase {
	import flash.filters.GlowFilter;
	import flash.text.engine.TextLine;

	import flashx.textLayout.compose.TextFlowLine;
	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.container.ScrollPolicy;
	import flashx.textLayout.edit.SelectionManager;
	import flashx.textLayout.elements.ParagraphElement;
	import flashx.textLayout.elements.SpanElement;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.formats.LineBreak;
	import flashx.textLayout.formats.TextAlign;
	import flashx.textLayout.formats.TextLayoutFormat;
	import flashx.textLayout.formats.VerticalAlign;
	import flashx.textLayout.tlf_internal;

	public class VText extends VComponent {
		public static const
			MIDDLE:uint = 1,		//размещение по вертикальному центру
			CONTAIN:uint = 2,				//режим вписывания
			BOTTOM:uint = 4,
			CENTER:uint = 8,
			CONTAIN_CENTER:uint = 10,		//2 | 8
			SELECTION:uint = 16
			;
		protected const textFlow:TextFlow = new TextFlow();
		private var span:SpanElement;

		public function VText(text:String = null, mode:uint = 0, color:uint = 0x1000000, fontSize:uint = 0) {
			mouseEnabled = false;

			const format:TextLayoutFormat = textFlow.format as TextLayoutFormat;
			if (color < 0x1000000) {
				format.color = color;
			}
			if (fontSize > 0) {
				format.fontSize = fontSize;
			}
			this.mode = mode;
			updateMode();

			value = text;
		}

		public function get format():TextLayoutFormat {
			return textFlow.format as TextLayoutFormat;
		}

		public function syncFormat(isUpdate:Boolean = false):void {
			textFlow.invalidateAllFormats();
			if (isUpdate) {
				syncContentSize(true);
			}
		}

		public function setBaseFormat(size:uint, color:uint):void {
			const format:TextLayoutFormat = textFlow.format as TextLayoutFormat;
			format.fontSize = size;
			format.color = color;
			textFlow.invalidateAllFormats();
		}

		public function setColor(value:uint):void {
			(textFlow.format as TextLayoutFormat).color = value;
			textFlow.invalidateAllFormats();
		}

		protected function updateMode():void {
			textFlow.textAlign = (mode & CENTER) != 0 ? TextAlign.CENTER : TextAlign.LEFT;
			if ((mode & CONTAIN) != 0) {
				textFlow.lineBreak = LineBreak.EXPLICIT;
				textFlow.verticalAlign = VerticalAlign.TOP;
			} else {
				textFlow.lineBreak = LineBreak.TO_FIT;
				if ((mode & MIDDLE) != 0) {
					textFlow.verticalAlign = VerticalAlign.MIDDLE;
				} else if ((mode & BOTTOM) != 0) {
					textFlow.verticalAlign = VerticalAlign.BOTTOM;
				} else {
					textFlow.verticalAlign = VerticalAlign.TOP;
				}
			}
			mouseChildren = (mode & SELECTION) != 0;
			if (mouseChildren) {
				if (!textFlow.interactionManager) {
					textFlow.interactionManager = new SelectionManager();
					//когда устанавливаем SelectionManager будет создан span
					if (textFlow.numChildren > 0 && !span) {
						span = (textFlow.getChildAt(0) as ParagraphElement).getChildAt(0) as SpanElement;
					}
				}
			} else {
				textFlow.interactionManager = null;
			}
		}

		public function setMode(value:uint):void {
			mode = value;
			updateMode();
			customUpdate();
		}

		public function set value(str:String):void {
			if (span) {
				span.text = str;
			} else {
				addSpan(str);
			}
			syncContentSize(true);
		}

		private function addSpan(str:String):void {
			var p:ParagraphElement = new ParagraphElement();
			span = new SpanElement();
			p.addChild(span);
			span.text = str;
			textFlow.addChild(p);
		}

		public function get value():String {
			return span ? span.text : '';
		}

		override public function dispose():void {
			textFlow.flowComposer.removeAllControllers();
			super.dispose();
		}

		protected function buildText(w:Number, h:Number):void {
			if (textFlow.flowComposer.numControllers == 0) {
				var cc:ContainerController = new ContainerController(this, w, h);
				cc.verticalScrollPolicy = ScrollPolicy.OFF;
				textFlow.flowComposer.addController(cc);
			} else {
				cc = textFlow.flowComposer.getControllerAt(0);
				cc.setCompositionSize(w, h);
			}
			textFlow.flowComposer.updateAllControllers();
		}

		public static function getComposeW(component:VComponent, isContain:Boolean):uint {
			var w:uint;
			if (!isContain) {
				w = component.calcAccurateW();
				if (component.maxW > 0 && w == 0) {
					return component.maxW;
				}
			}
			return w;
		}

		public static function getComposeH(component:VComponent):uint {
			var h:uint = component.calcAccurateH();
			if (component.maxH > 0 && h == 0) {
				return component.maxH;
			}
			return h;
		}

		public static function checkValidContentSize(component:VComponent, textFlow:TextFlow, isContain:Boolean):void {
			if (component.validContentSize && textFlow.flowComposer.numControllers > 0) {
				var cc:ContainerController = textFlow.flowComposer.getControllerAt(0);
				var v:Number = cc.compositionWidth;
				if (isNaN(v)) {
					v = 0;
				}
				if (getComposeW(component, isContain) != v) {
					component.validContentSize = false;
				} else {
					v = cc.compositionHeight;
					if (isNaN(v)) {
						v = 0;
					}
					if (getComposeH(component) != v) {
						component.validContentSize = false;
					}
				}
			}
		}

		//т.к. расчет содержимого производится с учетом компоновки, то нужно проверить что она не изменилась
		override public function get measuredWidth():uint {
			if (layoutW <= 0) {
				checkValidContentSize(this, textFlow, (mode & CONTAIN) != 0);
			}
			return super.measuredWidth;
		}

		override public function get measuredHeight():uint {
			if (layoutH <= 0) {
				checkValidContentSize(this, textFlow, (mode & CONTAIN) != 0);
			}
			return super.measuredHeight;
		}

		override protected function calcContentSize():void {
			var w:uint = getComposeW(this, (mode & CONTAIN) != 0);
			var h:uint = getComposeH(this);
			buildText(w > 0 ? w : NaN, h > 0 ? h : NaN);

			const cc:ContainerController = textFlow.flowComposer.getControllerAt(0);
			contentW = Math.ceil(cc.tlf_internal::contentWidth);
			contentH = Math.ceil(cc.tlf_internal::contentHeight);

			updateW = (w > contentW) ? w : contentW;
			updateH = (h > contentH) ? h : contentH;
		}

		override protected function customUpdate():void {
			if ((mode & CONTAIN) != 0) {
				containUpdate();
			} else {
				buildText(w, h);
			}
		}

		private function containUpdate():void {
			buildText(NaN, NaN);
			var len:int = numChildren;
			if (len == 0) {
				return;
			}

			var cc:ContainerController = textFlow.flowComposer.getControllerAt(0);
			var textW:Number = cc.tlf_internal::contentWidth;
			var textH:Number = cc.tlf_internal::contentHeight;

			var flag:Boolean = textW > w || textH > h;
			if (flag) {
				var scale:Number = (w / h <= textW / textH) ? w / textW : h / textH;
				textH = ((1 - scale) * textH) / 2; //смещение от верхнего края
			} else {
				scale = 1;
			}
			var isCenter:Boolean = (mode & CENTER) != 0;
			for (var i:uint = 0; i < len; i++) {
				var line:TextLine = getChildAt(i) as TextLine;
				if (i == 0) {
					var dy:Number = -line.getRect(null).y;
				}
				line.scaleX = scale;
				line.scaleY = scale;
				line.y = (line.userData as TextFlowLine).y + dy;
				if (flag) {
					line.y = line.y * scale + textH;
				}
				line.x = isCenter ? (w - line.width) / 2 : 0;
			}

			flag = (mode & MIDDLE) != 0;
			if (flag || (mode & BOTTOM) != 0) {
				textH = h - getChildAt(len - 1).getRect(this).bottom;
				if (flag) {
					textH /= 2;
				}
				for (i = 0; i < len; i++) {
					getChildAt(i).y += textH;
				}
			}
		}

		override public function add(component:VComponent, layout:Object = null, index:int = -1):void {
			throw new Error("VText don't use add method");
		}

		override public function remove(component:VComponent, isDispose:Boolean = true):void {
			throw new Error("VText don't use remove method");
		}

		public function assignW(value:int):VText {
			layoutW = value;
			return this;
		}

		public function assignMaxW(value:int):VText {
			maxW = value;
			return this;
		}

		CONFIG::debug
		override public function getToolPropList(out:Array):void {
			var str:String = value;
			out.push(
				new VOComponentItem('text', VOComponentItem.TEXT, str ? str.replace(new RegExp('\\n', 'g'), '\\n') : ''),
				new VOComponentItem('fontSize', VOComponentItem.DIGIT, format.fontSize),
				new VOComponentItem('contain', VOComponentItem.CHECKBOX, null, (mode & VText.CONTAIN) != 0, VText.CONTAIN),
				new VOComponentItem('middle', VOComponentItem.CHECKBOX, null, (mode & VText.MIDDLE) != 0, VText.MIDDLE),
				new VOComponentItem('center', VOComponentItem.CHECKBOX, null, (mode & VText.CENTER) != 0, VText.CENTER)
			);
			CONFIG::develop {
				var glowFilter:GlowFilter = filters && filters.length > 0 ? filters[0] as GlowFilter : null;
				if (glowFilter) {
					out.push(
						new VOComponentItem('glowSize', VOComponentItem.DIGIT, glowFilter.blurX),
						new VOComponentItem('glowStrength', VOComponentItem.DIGIT, glowFilter.strength)
					);
				}
			}
		}

		CONFIG::debug
		override public function updateToolProp(item:VOComponentItem):void {
			if (item.key == 'text') {
				var str:String = item.value as String;
				if (str) {
					str = str.replace(new RegExp('\\\\n', 'g'), '\n');
				}
				value = str;
			} else if (item.key == 'fontSize') {
				format.fontSize = item.getInt(10);
				syncFormat(true);
			} else {
				CONFIG::develop {
					if (item.key == 'glowSize' || item.key == 'glowStrength') {
						changeGlowFilter(item);
						return;
					}
				}
				if (item.checkbox) {
					mode |= item.bit;
				} else {
					mode &= ~item.bit;
				}
				setMode(mode);
			}
		}

		CONFIG::develop
		private function changeGlowFilter(item:VOComponentItem):void {
			var list:Array = filters;
			var glowFilter:GlowFilter = list[0];
			if (item.key == 'glowSize') {
				glowFilter.blurX = glowFilter.blurY = item.getInt(0, 255);
			} else {
				glowFilter.strength = item.getInt(0, 255);
			}
			filters = list;
		}

	} //end class
}