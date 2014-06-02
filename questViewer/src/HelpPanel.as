package {

	import flash.events.MouseEvent;

	import ui.UIFactory;

	import ui.vbase.*;

	public class HelpPanel extends VBaseComponent {

		private var box:VBox = new VBox(null, true, 5, VBox.TL_ALIGN);

		/**
		 * Конструхтор
 		 */
		public function HelpPanel() {
			setLayout({w:600, h:500});
			add(AssetManager.getEmbedSkin('VToolBgInputText', VSkin.STRETCH), {w:'100%', h:'100%'});
			add(box, {left:20, top:20, right:20});
			addListener(MouseEvent.CLICK, onClick);

			setHelp();
		}

		private function onClick(e:MouseEvent):void {
			visible = false
		}

		private function setHelp():void {
			var buttons:Array = [
				UIFactory.createEmbedButton('VToolGreenButtonBg', VSkin.STRETCH, new VLabel('ИмяКвеста/уровень'),{vCenter:0, hCenter:0}),
				UIFactory.createEmbedButton('VToolBlueButtonBg', VSkin.STRETCH, new VLabel('ИмяКвеста'),{vCenter:0, hCenter:0}),
				UIFactory.createEmbedButton('VToolRedButtonBg', VSkin.STRETCH, new VLabel('ИмяКвеста'),{vCenter:0, hCenter:0}),
				UIFactory.createEmbedButton('VToolBgInputText2', VSkin.STRETCH, new VLabel('ll'),{vCenter:0, hCenter:0}),
				UIFactory.createEmbedButton('VToolRedButtonBg', VSkin.STRETCH, new VLabel('fr'),{vCenter:0, hCenter:0}),
				UIFactory.createEmbedButton('VToolBlueButtonBg', VSkin.STRETCH, new VLabel('sc'),{vCenter:0, hCenter:0}),
				UIFactory.createEmbedButton('VToolOrangeButtonBg', VSkin.STRETCH, new VLabel('+'),{vCenter:0, hCenter:0})
			];
			var blayouts:Array = [
				{w:150, h:30},
				{w:100, h:30},
				{w:100, h:30},
				{w:16, h:16},
				{w:16, h:16},
				{w:16, h:16},
				{w:20, h:20}
			]

			var texts:Array = [
				'это кнопка квеста или уровня. при клике по ней нарисуется дерево,<br/> начиная от этого квеста/уровня',
				'если кнопка синяя, значит, она продублирована в этом же дереве<br/> и часть продолжений дерева, идущих от этой кнопки, опущена',
				'это тупиковый квест. по прохождении его цепочка обрывается',
				'это дополнительная зависимость квеста, который находится под этой кнопкой.<br/> при наведении раскукоживается',
				'это левел квеста, который находится под этой кнопкой. при наведении раскукоживается',
				'это дополнительная зависимость квеста, который находится под этой кнопкой.<br/> она продублирована в графе',
				'это плюсик. он может разворачивать и сворачивать элементы графа.<br/>рисуется при любых ветвлениях вниз'
			]

			var boxlist:Array = [];

			boxlist.push(new VLabel('<p fontWeight="bold">Тулза для визуализации дерева квестов.</p><br/><br/>Кнопки вверху предназначены для навигации и поиска.<br/>Второй ряд - это уровни, на которых открываются квесты без превов.<br/>Зависимости идут сверху вниз<br/><span fontWeight="bold" color="#3333FF">[7]</span> - номер лайна.<br/><span color="#3333FF"> есть стори |</span>| нет стори<br/><br/>'));

			for (var i:uint = 0; i < buttons.length; i++){
				addHelp(buttons[i], blayouts[i], texts[i], boxlist);
			}

			box.addList(boxlist);

		}

		private function addHelp(vb:VBaseComponent, vbLayout:Object, txt:String, list:Array):void {

			var box1:VBox = new VBox(null, false);
			vb.setLayout(vbLayout);
			box1.addList([vb, new VLabel(txt)]);
			list.push(box1);
		}
	}
}
