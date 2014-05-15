package {

	import com.adobe.images.PNGEncoder;

	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.geom.Point;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	import ui.UIFactory;

	import ui.vbase.*;

	import vo.VOQuest;
	[SWF(backgroundColor="0xDDFFBB" , width="680" , height="720")]
	public class Quest extends Sprite {
		private var startbn:VButton;
		private var searchBox:VBaseComponent = new VBaseComponent();
		public var mainpanel:VBaseComponent = new VBaseComponent();
		private var fileR:FileReference = new FileReference();

		private var quests:Object = {};
		private var tf:TextField = new TextField();
		private var questPanel:VBox;

		private var usedVoqn:Array = [];
		private var usedQV:Object = {};
		private var pos:Point;

		private var kinds:Object = {};

		private var lastButton:VButton;
		private var stack:Array = [];
		private var currentData:*;
		private var helpPanel:HelpPanel = new HelpPanel();

		public static var instance:Quest;
		public var folds:Array = []/*of QuestView*/;

		/**
		 * Конструхтор
 		 */
		public function Quest() {
			instance = this;
			mainpanel.setLayout({w:600, h:400});
			mainpanel.geometryPhase();
			mainpanel.graphics.beginFill(0,0.05);
			mainpanel.graphics.drawRect(0,0, 4000, 4000);
			mainpanel.graphics.endFill();
			mainpanel.y = 120;
			stage.addChild(mainpanel);

			searchBox.setLayout({w:600, h:400});
			searchBox.geometryPhase();
			stage.addChild(searchBox);

			var lb:VLabel =  new VLabel('жди!')
			searchBox.add(lb, {left:40, top:25});
			startbn = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:100, h:20,vCenter:0, hCenter:0}, new VLabel('жми!'), {vCenter:0, hCenter:0});
			searchBox.add(startbn, {left:20, top:20});

			startbn.addClickListener(onClick);

			mainpanel.addListener(MouseEvent.MOUSE_DOWN, dragStart);
			mainpanel.addListener(MouseEvent.MOUSE_UP, dragStop);
			mainpanel.addListener(MouseEvent.CLICK, click);
			searchBox.addListener(MouseEvent.CLICK, clickLevels);
			//mainpanel.addListener(MouseEvent.MOUSE_WHEEL, scal);

			searchBox.add(helpPanel, {hCenter:0, top:100});
			helpPanel.visible = false;
		}

		private var isClick:Boolean = true;

		private function dragStart(e:MouseEvent):void {
			isClick = true;
			pos = new Point(mouseX, mouseY);mainpanel.startDrag();
		}

		private function dragStop(e:MouseEvent):void {
			isClick = pos.x == mouseX && pos.y == mouseY;
			mainpanel.stopDrag();
		}

		private static const SCALE:Number = 0.05;

		private function scaleMinus(e:MouseEvent):void {
			mainpanel.scaleX -= SCALE;
			mainpanel.scaleY -= SCALE;
		}
		private function scalePlus(e:MouseEvent):void {
			mainpanel.scaleX += SCALE;
			mainpanel.scaleY += SCALE;
		}

		private function scal(e:MouseEvent):void {
			var delta:Number = 0.02 * (e.delta < 0 ? 1 : -1);
			mainpanel.scaleX -= delta;
			mainpanel.scaleY -= delta;
		}

		private function saveKinds(e:MouseEvent):void {
/*			mainpanel.x = 0;
			mainpanel.y = 120;

			if (questPanel){
				mainpanel.remove(questPanel);
			}

			questPanel = new VBox(null, true, 15, VBox.TL_ALIGN);
			mainpanel.add(questPanel, {left:20, top:100});*/

			var text:String = 'Кайнды таргетов по алфавиту:';
			var a:Array = [];
			for (var kind:String in kinds){
				a.push(kind + ':' + kinds[kind]);
			}
			a.sort();
			for each(kind in a){
				text += '\n' + kind;
			}
			var byteArray:ByteArray = new ByteArray();
			byteArray.writeMultiByte(text, 'utf-8');
			var fileReference:FileReference=new FileReference();
			fileReference.save(byteArray, '.txt');

			//questPanel.add(new VLabel(text));
		}

		/**
		 * Выбор файла с конфом
		 * @param e
		 */
		private function onClick(e:MouseEvent):void{
			var filter:FileFilter = new FileFilter("Quests.conf", "*.conf;*.conf.example");
			fileR.browse([filter]);
			fileR.addEventListener(Event.SELECT, selectHandler);
			fileR.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			fileR.addEventListener(Event.COMPLETE, completeHandler);

		}

		/**
		 * клик по борде
		 * @param e
		 */
		private function click(e:MouseEvent):void {
			if (isClick && e.target is VButton){
				if (e.target.data != null){
					onClickQuest(e.target);
				}
			}
		}
		private function clickLevels(e:MouseEvent):void {
			if (e.target is VButton && !(e.target == lastButton)){
				if (e.target.data != null){
					onClickQuest(e.target);
				}
			}
		}

		/**
		 * Загрузка файла
		 * @param e
		 */
		private function selectHandler(e:Event):void{
			startbn.visible = false;
			startbn.removeListener(MouseEvent.CLICK, onClick);
			startbn.dispose();
			fileR.load();
		}

		private function progressHandler(e:ProgressEvent):void{
		}

		/**
		 * Загрузился файл с квестами
		 * @param e
		 */
		private function completeHandler(e:Event):void{
			fileR.data.endian = Endian.BIG_ENDIAN;
			var str:String = fileR.data.readUTFBytes(fileR.data.bytesAvailable);

			//вырезаем закомментированные строки
			var r:RegExp = /\/\/.*?\n/;
			str = replaceAll(r,str);
			var obj:*;
			try {
				obj = JSON.parse(str);
			} catch (e:Error) {
				searchBox.add(new VLabel('Выбранный файл содержит ошибку!'), {left:200, top:20});
				return;
			}

			for (var name:String in obj){
				var voq:VOQuest = new VOQuest();
				voq.qname = name;
				for (var field:String in obj[name]){
					if (voq.hasOwnProperty(field)){
						voq[field] = obj[name][field];
					}
				}
				quests[voq.qname] = voq;

				// вычитаем кайнды таргетов
				if (obj[name]['targets']){
					for each (var targ:Object in obj[name]['targets']){
						if (targ.kind != ''){
							if (kinds.hasOwnProperty(targ.kind)){
								kinds[targ.kind]++;
							} else {
								kinds[targ.kind] = 1;
							}
						}
					}
				}
			}

			linkQuests();

			addEmptyLevels();

			//quests = quests.sortOn(['qname', 'level', 'nesting_level'])

			tf.border = true;
			tf.width = 240;
			tf.height = 30;
			tf.backgroundColor = 0xFFFFFF;
			tf.background = true;
			tf.type = TextFieldType.INPUT;
			var format1:TextFormat = new TextFormat();
			format1.font="Arial";
			format1.size = 18;
			tf.defaultTextFormat = format1;
			tf.x = 20;
			tf.y = 20;
			searchBox.addChild(tf);

			var button:VButton = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:100, h:30, vCenter:0, hCenter:0}, new VLabel('поиск'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:280, top:20});
			button.addClickListener(search);

			button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:150, h:30, vCenter:0, hCenter:0}, new VLabel('помощь'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:350, top:20});
			button.addClickListener(onClickHelp);

			button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:150, h:30, vCenter:0, hCenter:0}, new VLabel('сохр'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:500, top:20});
			button.addClickListener(onClickSave);

			stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

			lastButton = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:150, h:30, vCenter:0, hCenter:0}, new VLabel('назад'), {vCenter:0, hCenter:0});
			searchBox.add(lastButton, {left:440, top:20});
			lastButton.addClickListener(onClickBack);
			lastButton.disabled = true;

			searchBox.add(new VLabel('Масштаб'), {left:565, top:8});
			button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:30, h:30, vCenter:0, hCenter:0}, new VLabel('-'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:560, top:20});
			button.addClickListener(scaleMinus);
			button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:30, h:30, vCenter:0, hCenter:0}, new VLabel('+'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:590, top:20});
			button.addClickListener(scalePlus);

			button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH),
					{w:30, h:30, vCenter:0, hCenter:0}, new VLabel('kinds'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:630, top:20});
			button.addClickListener(saveKinds);

		}

		private function linkQuests():void {
			for (var qname:String in quests){
				var voq:VOQuest = quests[qname];
				if (voq.prev){
					for each (var p:* in voq.prev){
						if (p is Array){
							voq.prevQ.push(quests[p[0]]);
						} else {
							voq.prevQ.push(quests[p]);
						}
					}
				}

				for (var qname2:String in quests){
					var voq2:VOQuest = quests[qname2];
					var voq1:VOQuest;
					if (voq2.prev){
						for each (var link:* in voq2.prev){
							voq1 = null;
							if (link is Array){
								voq1 = quests[link[0]];
							} else {
								voq1 = quests[link];
							}
							if (voq1 && voq1.qname == voq.qname){
								voq.nextQ.push(voq2);
							}
						}
					}
				}
			}
		}

		/**
		 * Добавляем кнопки уровней, из которых вылезают квесты
		 */
		private function addEmptyLevels():void {
			var levels:Array = [];
			for (var qname:String in quests){
				var voq:VOQuest = quests[qname];
				if (voq.level && !voq.prev && levels.indexOf(voq.level) == -1){
					levels.push(voq.level);
				}
			}
			levels.sort(Array.NUMERIC);
			var arr:Array = [];
			for each (var i:uint in levels){
				arr.push(createQuestButton(i));
			}

			var box:VBox = new VBox(null, false, 0);
			box.addList(arr);
			searchBox.add(box, {left:0, top:60});
		}

		/**
		 * Вырезаем закомментированные строки регуляркой
		 * @param r
		 * @param s
		 * @return
		 */
		private function replaceAll(r:RegExp, s:String):String{
			while((r.test(s))!=false){
				s = s.replace(r, "");
			}
			return s;
		}

		/**
		 * Делаем, чтобы кнопочка доп. зависимости кукожилась по наведению
		 * @param bn
		 */
		private function addFold(bn:VButton):void {
			bn.skin.setLayout({w:16, h:16});
			bn.icon.setLayout({w:16, h:16});
			//bn.geometryPhase();
			bn.addListener(MouseEvent.MOUSE_OVER, foldOn);
			bn.addListener(MouseEvent.MOUSE_OUT, foldOff);
			var index:String = (bn.data is VOQuest) ? bn.data.qname : (bn.data + 'l');
			if (usedQV[index]){
				usedQV[index].push(bn);
			} else {
				usedQV[index] = [bn];
			}
			//trace(index, usedQV[index].length)
 		}

		private function foldOn(e:MouseEvent):void {
			var bn:VButton = e.target as VButton;
			bn.icon.setLayout({w:0});
			//bn.icon.geometryPhase();
			bn.skin.setLayout({w:bn.icon.contentWidth + 5});
			//(bn.parent as VBox).geometryPhase();
		}
		private function foldOff(e:MouseEvent):void {
			var bn:VButton = e.target as VButton;
			bn.skin.setLayout({w:16});
			bn.icon.setLayout({w:16});
			//(bn.parent as VBox).geometryPhase();

		}

		/**
		 * клик по любому квесту
		 * @param e
		 */
		private function onClickQuest(e:*):void {
			try {
				folds = [];
				//usedQV = {};
				//usedVoqn = [];
				mainpanel.x = 0;
				mainpanel.y = 120;

				if (questPanel){
					mainpanel.remove(questPanel);
				}

				questPanel = new VBox(null, true, 15, VBox.TL_ALIGN);
				mainpanel.add(questPanel, {left:20, top:100});
				var cur:VButton = e is VButton ? e : e.target as VButton;

				if (flagback){
					flagback = false;
				} else {
					lastButton.data = currentData;
					lastButton.disabled = false;
					stack.push(currentData);
					currentData = cur.data is VOQuest ? cur.data.qname : cur.data;
				}

				var qv:QuestView = new QuestView(cur.data/*, onClickQuest*/);
				usedVoqn = cur.data is VOQuest ? [cur.data] : [];
				usedQV = {};
				questPanel.add(qv);
				//trace('start rec')
				rec(qv, cur.data, true);
				//trace('end rec');
			} catch (e:Error){
				trace("Global Error:", e, e.message, e.getStackTrace());
			}
		}

		//флаг, что мы тычем кнопку бэк и в стек не надо добавлять эти данные
		private var flagback:Boolean = false;

		/**
		 * возврат в предыдущее состояние поиска
		 * @param e
		 */
		private function onClickBack(e:MouseEvent):void {
			flagback = true;
			var data:* = stack.pop();
			if (data){
				lastButton.data = data is String ? quests[data] : data;
				onClickQuest(lastButton);
				lastButton.disabled = stack.length == 0;
			} else {
				lastButton.disabled = true;
			}

		}

		/**
		 * добавляем всю хурму рекурсивно до упора
		 * @param qv вьюха
		 * @param voq - квест
		 * @param isFirst - для первого квеста в рекурсии рисуем зависимости принудительно
		 * @param parentvoq квест родитель
		 */
		public function rec(qv:QuestView, voq:*, isFirst:Boolean = false, parentvoq:* = null):void {
			var next:Array = [];
			var button:VButton;
			if (voq is VOQuest){

				for each (var voqn:VOQuest in voq.nextQ){
					if (usedVoqn.indexOf(voqn) == -1){
						usedVoqn.push(voqn);
						var qv1:QuestView = new QuestView(voqn);
						//if ((voq.nextQ.length == 1) || isFirst){
							rec(qv1, voqn, false, qv.data);
						//}
						next.push(qv1);
					} else {
						qv.button.setSkin(AssetManager.getEmbedSkin('VToolBlueButtonBg', VSkin.STRETCH | VSkin.CONTAIN), {h:30, vCenter:0, hCenter:0, w:50});
						qv.button.skin.setLayout({w:qv.button.icon.contentWidth+20})
						//qv.geometryPhase();

						if (usedQV[voq.qname]){
							for each (button in usedQV[voq.qname]){
								button.setSkin(AssetManager.getEmbedSkin('VToolBlueButtonBg', VSkin.STRETCH), {h:16, vCenter:0, hCenter:0, w:16});
								//button.geometryPhase();
							}
						}
					}
				}

				var prev:Array = [];
				if (voq.prev){

					for each (var p:* in voq.prev){
						if (p is Array){
							button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolBgInputText', VSkin.STRETCH),
									{h:30,vCenter:0, hCenter:0}, new VLabel(p[0] +  "::" + p[1]), {vCenter:0, hCenter:0});
							button.data = p[0];
						} else {
							button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolBgInputText', VSkin.STRETCH),
									{h:30,vCenter:0, hCenter:0}, new VLabel(p), {vCenter:0, hCenter:0});
							button.data = p;
						}

						if (quests[button.data] && quests[button.data] != parentvoq){
							button.data = quests[button.data];
							prev.push(button);
							addFold(button);
						}
					}
				}

				if (voq.level && voq.level != parentvoq){
					button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolRedButtonBg', VSkin.STRETCH),
							{h:30,vCenter:0, hCenter:0}, new VLabel(voq.level + ' level'), {vCenter:0, hCenter:0});
					button.data = voq.level;
					addFold(button);
					prev.push(button);
				}

				if (prev.length > 0){
					qv.setPrev(prev);
				}

			} else {
				for each (var voq1:VOQuest in quests){
					if (voq1.level == voq){
						usedVoqn.push(voq1);
						qv1 = new QuestView(voq1/*, onClickQuest*/);
						//if (next.length == 0 || isFirst){
							rec(qv1, voq1, false, qv.data);
						//}
						next.push(qv1);
					}
				}
			}

			if (next.length){
				qv.setNext(next);
				if (next.length > 1){
					folds.push(qv);
				}
			}
		}

		private function onKeyUp(e:KeyboardEvent):void {
			if (e.keyCode == Keyboard.ENTER){
				search(null);
			}
		}

		private function search(e:MouseEvent):void {
			if (int(tf.text) > 0){
				searchLevel();
			} else {
				searchQuest();
			}
		}

		/**
		 * Искать квест по имени
		 * @param e
		 */
		private function searchQuest():void {
			for each (var voq:VOQuest in quests){
				if (voq.qname.toLowerCase() == tf.text.toLowerCase()){
					var bn:VButton = createQuestButton(voq);
					onClickQuest(bn);
					return;
				}
			}

			tf.text = 'Такой квест не найден!';
		}

		/**
		 * Искать квест по уровню
		 * @param e
		 */
		private function searchLevel():void {
			for each (var voq:VOQuest in quests){
				if (int(tf.text) > 0 && voq.level == int(tf.text)){
					var bn:VButton = createQuestButton(voq.level);
					onClickQuest(bn);
					return;
				}
			}

			tf.text = 'Уровень не найден!';
		}

		private function onClickHelp(e:MouseEvent):void{
			helpPanel.visible = !helpPanel.visible;
		}


		private function onClickSave(e:MouseEvent):void {
			var bitmapData:BitmapData=new BitmapData(mainpanel.contentWidth, mainpanel.contentHeight);
			bitmapData.draw(mainpanel);
			var byteArray:ByteArray = PNGEncoder.encode(bitmapData);
			var fileReference:FileReference=new FileReference();
			fileReference.save(byteArray, '.png');
		}

		/**
		 * в имя квеста из линейки в скобках дописывается длина линейки
		 * @param voq
		 * @return
		 */
		private function getMaxNestingLevel(voq:VOQuest):String {
			if (voq.nesting_level){
				var mnl:int = voq.nesting_level;
				var clname:String = voq.qname.replace(voq.nesting_level.toString(), '');

				for each (var q:VOQuest in quests){
					if (q.qname.indexOf(clname) == 0){
						mnl = Math.max(mnl, q.nesting_level);
					}
				}
				return '(' + mnl + ')';
			}
			return '';
		}

		/**
		 * Квестовая кнопка
		 * @param data VOQuest | int (
		 * @param skin
		 * @return
		 */
		private function createQuestButton(data:*, skin:String = 'VToolGreenButtonBg'):VButton{
			var button:VButton = UIFactory.createButton(AssetManager.getEmbedSkin(skin, VSkin.STRETCH | VSkin.CONTAIN),
					{h:30, vCenter:0, hCenter:0}, new VLabel(
					data is VOQuest ? data.qname + getMaxNestingLevel(data) : '' + data), {vCenter:0, hCenter:0});
			button.data = data;
			//button.addClickListener(onClickQuest);
			return button;
		}
	}
}
