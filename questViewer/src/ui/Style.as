package ui {
	import flash.display.DisplayObject;
	import flash.filters.ColorMatrixFilter;
	import flash.filters.DropShadowFilter;
	import flash.filters.GlowFilter;
	import flash.text.engine.FontLookup;
	import flash.text.Font;
	import flashx.textLayout.elements.Configuration;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.formats.TextLayoutFormat;
	import flashx.textLayout.formats.WhiteSpaceCollapse;
	import ui.vbase.AssetManager;
	
	public class Style {
		public static const GREY_FILTER:ColorMatrixFilter = new ColorMatrixFilter([
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0.3086000084877014, 0.6093999743461609, 0.0820000022649765, 0, 0,
			0, 0, 0, 1, 0
		]);
		//value = 162.56 (.28 * 127 + 127), brightness = .5 * (127 - value), value = value / 127
		//для консрастности 22 берется .28 (см таблицу AdjustColor.s_arrayOfDeltaIndex)
		//value = 1.28, brightness = -17.78
		//value подставляется в [0][0], [1][1], [2][2]
		//brightness подставляется в [0][4], [1][4], [2][4]
		public static const CONTRAST_FILTER:ColorMatrixFilter = new ColorMatrixFilter([
			1.28, 0, 0, 0, -17.78,
			0, 1.28, 0, 0, -17.78,
			0, 0, 1.28, 0, -17.78,
			0, 0, 0, 1, 0
		]);
		
		public static const
			purpleRGB:uint = 0x722172,
			cyanRGB:uint = 0x004194,
			blueRGB:uint = 0x008196,
			redRGB:uint = 0x940014,
			bgRGB:uint = 0x8CAFBE;

		public static const digit:String = ' fontFamily="Hobo Std"',
			hint:String = ' color="0x591100" fontSize="15"',
			redColor:String = ' color="#' + redRGB.toString(16) + '"',
			violetColor:String = ' color="#460966"',
			blueColor:String = ' color="#' + blueRGB.toString(16) + '"',
			brownColor:String = ' color="#4C1F01"',
			purpleColor:String = ' color="#' + purpleRGB.toString(16) + '"',
			def_digit:String = ' fontFamily="Hobo Std" color="#940014"',
			greenColor:String = ' color="#105F13"',
			yellowTextColor:String = ' color="#FCFC9D"',
			cyanColor:String = ' color="#' + cyanRGB.toString(16) + '"',
			yellowColor:String = ' color="#FFCF2B"',
			textLightColor:String = ' color="#FFFFCA"';
			
		public static const
			headerText:String = yellowTextColor + ' textAlign="center" fontWeight="bold"',
			dialogHeaderText:String = yellowColor+' fontWeight="bold"',
			titleText:String = blueColor + ' fontWeight="bold"',
			actionText:String = ' fontSize="14" ' + brownColor;
		
		public static function applyBigDigitGlow(obj:DisplayObject):void {
			obj.filters = [new GlowFilter(0xFFFFCA, 1, 4, 4, 5)];
		}
		
		public static function applySmallDigitGlow(obj:DisplayObject):void {
			obj.filters = [new GlowFilter(0xFFFFCA, 1, 2, 2, 10)];
		}
		
		/**
		 * Для текста размером шрифта 16 и ниже
		 * Идет замещение всех фильтров
		 * 
		 * @param		obj			Целевой объект
		 * @param		color		Цвет
		 */
		public static function applyTitleGlow(obj:DisplayObject, color:uint):void {
			obj.filters = [new GlowFilter(color, 1, 4, 4, 4)];
		}

		public static function applyHeaderFilter(obj:DisplayObject, isDropShadow:Boolean = false, glowStrength:uint = 8):void {
			var list:Array = [];
			if (isDropShadow) {
				list.push(new DropShadowFilter(2, 145, 0x704D1A, 1, 2, 2, 4));
			}
			list.push(new GlowFilter(0x2D1F05, 1, 2, 2, glowStrength));
			obj.filters = list;
		}
		
		/**
		 * Для текста размером шрифта 18 и выше
		 * 
		 * @param		obj			Целевой объект
		 * @param		color		Цвет
		 */
		public static function applyBigTitleGlow(obj:DisplayObject, color:uint):void {
			obj.filters = [new GlowFilter(color, 1, 4, 4, 8)];
		}
		
		public static function init():void {
			XML.ignoreProcessingInstructions = false;
			XML.ignoreWhitespace = false;
			
			var config:Configuration = TextFlow.defaultConfiguration;
			config.inlineGraphicResolverFunction = AssetManager.inlineGraphicResolverFunction;
			config.manageTabKey = false;
			
			var format:TextLayoutFormat = config.textFlowInitialFormat as TextLayoutFormat;
				format.fontFamily = 'Myriad Pro';
				format.fontLookup = FontLookup.EMBEDDED_CFF;
			format.fontSize = 18;
			format.lineHeight = '100%';
			format.color = cyanRGB;
			format.whiteSpaceCollapse = WhiteSpaceCollapse.PRESERVE;
		}
		
	} //end class
}