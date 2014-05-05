package {

	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.utils.Endian;

	import ui.UIFactory;
	import ui.vbase.AssetManager;

	import ui.vbase.*;
	import ui.vbase.VButton;

	import vo.VOQuest;
	[SWF(backgroundColor="0xDDFFBB" , width="680" , height="720")]
	public class Quest extends Sprite {
		private var searchBox:VBaseComponent = new VBaseComponent();
		private var mainpanel:VBaseComponent = new VBaseComponent();
		private var fileR:FileReference = new FileReference();

		private var quests:Array = [];
		private var tf:TextField = new TextField();
		private var questPanel:VBox;

		private var pos:int = 0;

		/**
		 * Конструхтор
 		 */
		public function Quest() {
			mainpanel.setLayout({w:600, h:400});
			mainpanel.geometryPhase();
			stage.addChild(mainpanel);

			searchBox.setLayout({w:600, h:400});
			searchBox.geometryPhase();
			stage.addChild(searchBox);

			var lb:VLabel =  new VLabel('жди!')
			searchBox.add(lb, {left:40, top:25});
			var button:VButton = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH), {w:100, h:20,vCenter:0, hCenter:0}, new VLabel('жми!'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:20, top:20});

			button.addClickListener(onClick);

			mainpanel.addListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):void{pos = mouseX + mouseY * 100;mainpanel.startDrag()});
			mainpanel.addListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):void{mainpanel.stopDrag()});
		}

		/**
		 * Выбор файла с конфом
		 * @param e
		 */
		private function onClick(e:MouseEvent):void{

			e.target.visible = false;
			var filter:FileFilter = new FileFilter("Quests.conf", "*.conf;*.conf.example");
			fileR.browse([filter]);
			fileR.addEventListener(Event.SELECT, selectHandler);
			fileR.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			fileR.addEventListener(Event.COMPLETE, completeHandler);

		}

		/**
		 * Загрузка файла
		 * @param e
		 */
		private function selectHandler(e:Event):void{
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

			var obj:* = JSON.parse(str);
			for (var name:String in obj){
				var voq:VOQuest = new VOQuest();
				voq.qname = name;
				for (var field:String in obj[name]){
					if (voq.hasOwnProperty(field)){
						voq[field] = obj[name][field];
					}
				}
				quests.push(voq);
			}

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

			var button:VButton = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH), {w:100, h:30, vCenter:0, hCenter:0}, new VLabel('поиск'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:280, top:20});
			button.addClickListener(onClickSearch);

			button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolOrangeButtonBg', VSkin.STRETCH), {w:150, h:30, vCenter:0, hCenter:0}, new VLabel('поиск по уровню'), {vCenter:0, hCenter:0});
			searchBox.add(button, {left:350, top:20});
			button.addClickListener(onClickSearchLevel);

		}

		/**
		 * Вырезаем закомментированные строки регуляркой
		 * @param r
		 * @param s
		 * @return
		 */
		private function replaceAll(r:RegExp,s:String):String{
			while((r.test(s))!=false){
				s = s.replace(r, "")
			}
			return s;
		}

		/**
		 * клик по любому квесту
		 * @param e
		 */
		private function onClickQuest(e:*):void {
			if (pos != 0 && mouseX + mouseY * 100 != pos){return;}
			if (questPanel){
				mainpanel.remove(questPanel);
			}

			questPanel = new VBox(null, true, 15, VBox.TL_ALIGN);
			var cur:VButton = e is VButton ? e : e.target as VButton;
			var prev:Array = [];
			var next:Array = [];
			// если кнопка была квестом или таргетом
			if (cur.data is VOQuest){
				var voq:VOQuest = cur.data as VOQuest;

				// если есть ограничение по уровню, то добавим кнопку левела
				if (voq.level){
					var button:VButton = createQuestButton(voq.level, 'VToolRedButtonBg');
					prev.push(button);
				}

				// добавим все предыдущие квесты
				if (voq.prev){
					for each (var p:* in voq.prev){
						if (p is Array){
							button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolGreenButtonBg', VSkin.STRETCH), {/*w:200,*/ h:30,vCenter:0, hCenter:0}, new VLabel(p[0] +  "::" + p[1]), {vCenter:0, hCenter:0});
							button.data = p[0];
						} else {
							button = UIFactory.createButton(AssetManager.getEmbedSkin('VToolGreenButtonBg', VSkin.STRETCH), {/*w:200,*/ h:30,vCenter:0, hCenter:0}, new VLabel(p), {vCenter:0, hCenter:0});
							button.data = p;
						}


						for each (var voq1:VOQuest in quests){
							if (voq1.qname == button.data){
								button.data = voq1;
								button.addClickListener(onClickQuest);
								prev.push(button);
								break;
							}
						}
					}
				}

				// добавим квесты, которые зависят от этого квеста или от его цели
				for each (var voq2:VOQuest in quests){
					if (voq2.prev){
						voq1 = null;
						if (voq2.prev[0] is Array){
							voq1 = getQuest(voq2.prev[0][0]);
						} else {
							voq1 = getQuest(voq2.prev[0]);
						}
						if (voq1 && voq1.qname == voq.qname){
							button = createQuestButton(voq2);
							next.push(button);
						}
					}
				}
			} else { // добавим квесты, открывающиеся по уровню
				for each (voq2 in quests){
					if (voq2.level == cur.data){
						button = createQuestButton(voq2);
						next.push(button);
					}
				}
			}

			// нарисуем кнопки

			if (prev.length){
				var lb:VLabel = new VLabel("Необходимо завершить:");
				lb.setLayout({w:200});
				prev.unshift(lb);
				var vb:VBox = new VBox(null, false);
				vb.addList(prev);
				questPanel.add(vb);
			}

			button = createQuestButton(cur.data, 'VToolBlueButtonBg');
			vb = new VBox(null, false);
			lb = new VLabel(cur.data is VOQuest ? "Текущий квест:" : "Текущий уровень:");
			lb.setLayout({w:200});
			vb.addList([lb, button]);
			questPanel.add(vb);

			if (next.length){
				lb = new VLabel("По прохождению откроется:");
				lb.setLayout({w:200});
				next.unshift(lb);
				vb = new VBox(null, false);
				vb.addList(next);
				questPanel.add(vb);
			}

			mainpanel.add(questPanel, {left:20, top:100});
		}

		/**
		 * Берём квест по имени
		 * @param name
		 * @return
		 */
		private function getQuest(name:String):VOQuest{
			for each (var voq:VOQuest in quests){
				if (voq.qname == name){
					return voq;
				}
			}

			return null;
		}

		/*
		private function recursion(voq:*, сur:VOQuest, next:Array):void {
			if (voq is VOQuest){
				// если есть ограничение по уровню, то добавим кнопку левела
				if (voq.level){
					var button:VButton = createQuestButton(voq.level, 'VToolRedButtonBg');
					prev.push(button);
				}

				// добавим квесты, которые зависят от этого квеста или от его цели
				for each (var voq2:VOQuest in quests){
					if (voq2.prev){
						voq1 = null;
						if (voq2.prev[0] is Array){
							voq1 = getQuest(voq2.prev[0][0]);
						} else {
							voq1 = getQuest(voq2.prev[0]);
						}
						if (voq1 && voq1.qname == voq.qname){
							button = createQuestButton(voq2);
							next.push(button);
						}
					}
				}
			} else { // добавим квесты, открывающиеся по уровню
				for each (voq2 in quests){
					if (voq2.level == voq){
						button = createQuestButton(voq2);
						next.push(button);
					}
				}
			}
		}
		*/

		/**
		 * Искать квест по имени
		 * @param e
		 */
		private function onClickSearch(e:MouseEvent):void {
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
		private function onClickSearchLevel(e:MouseEvent):void {
			for each (var voq:VOQuest in quests){
				if (int(tf.text) > 0 && voq.level == int(tf.text)){
					var bn:VButton = createQuestButton(voq.level);
					onClickQuest(bn);
					return;
				}
			}

			tf.text = 'Уровень не найден!';
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
			var button:VButton = UIFactory.createButton(AssetManager.getEmbedSkin(skin, VSkin.STRETCH | VSkin.CONTAIN), {/*w:200,*/ h:30, vCenter:0, hCenter:0}, new VLabel(
					data is VOQuest ? data.qname  + getMaxNestingLevel(data) : 'level ' + data), {vCenter:0, hCenter:0});
			button.data = data;
			button.addClickListener(onClickQuest);
			return button;
		}
	}
}
