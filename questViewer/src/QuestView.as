package {
	import flash.events.MouseEvent;

	import ui.UIFactory;
	import ui.vbase.*;
	import vo.VOQuest;

	public class QuestView extends VBaseComponent{

		public var button:VButton;
		public var fold:VButton;
		private var container:VBox = new VBox(null, true, 0, VBox.TL_ALIGN);
		private var prevBox:VBox = new VBox(null, false, 2, VBox.TL_ALIGN);
		public var btBox:VBox = new VBox(null, false);
		public var nextBox:VBox = new VBox(null, false, 5, VBox.TL_ALIGN);
		public var data:*;
		private var folded:Boolean = true;
		private var nextList:Array = [];
		//public var parentFold:QuestView;

		public function QuestView(data:*, callback:Function) {
			this.data = data;
			var skin:String = data is VOQuest && data.nextQ.length == 0 ? 'VToolRedButtonBg' : 'VToolGreenButtonBg';
			button = UIFactory.createButton(AssetManager.getEmbedSkin(skin, VSkin.STRETCH | VSkin.CONTAIN),
					{h:30, vCenter:0, hCenter:0}, new VLabel(
							data is VOQuest ? data.qname /*+ data.maxnestinglevel*/ : 'level ' + data), {vCenter:0, hCenter:0});
			button.data = data;
			button.addClickListener(callback);

			add(container);
			btBox.addList([button]);
			container.addList([prevBox, btBox, nextBox]);
		}

		/**
		 * Свернуть/развернуть
		 */
		public function clickFold(e:MouseEvent):void {
			//nextBox.graphics.clear();
/*			if (e == null){
				folded = true;
			}*/

			if (folded){
				//Quest.instance.rec(this, data/*, true*/);
				nextBox.visible = true;

				nextBox.addList(nextList);
				//nextBox.geometryPhase();
				geometryPhase();
				if (nextList.length){
					//if (parentFold && e){
						//parentFold.clickFold(null);
						//parentFold.clickFold(null);
					//}
					//nextBox.graphics.clear();
					nextBox.graphics.lineStyle(2,0x555555);
					nextBox.graphics.moveTo(30,0);
					nextBox.graphics.lineTo(nextBox.list[nextBox.list.length - 1].x + 30, 0);
				}
			} else {
				nextBox.visible = false;
 				nextList = toArray(nextBox.list);
				nextBox.graphics.clear();
				nextBox.removeAll(false);
			}


			folded = !folded;
			fold.setIcon(new VLabel(folded ? '+' : '-'), {vCenter:0, hCenter:0});
		}

		private function toArray(vec:Vector.<VBaseComponent>):Array{
			var a:Array = [];
			for each (var vbc:VBaseComponent in vec){
				a.push(vbc);
			}
			return a;
		}

		/**
		 * выставить зависимости
		 * @param prev
		 */
		public function setPrev(prev:Array):void {
			prevBox.addList(prev);
			//geometryPhase();
		}

		/**
		 * выставить продолжения
		 * @param next
		 */
		public function setNext(next:Array):void {
			//next.sort(sortfunc)
			nextList = next;
			if (next.length == 1){
				nextBox.addList(next);
			}
			//nextBox.geometryPhase();
			/*geometryPhase();
			nextBox.graphics.clear();
			nextBox.graphics.lineStyle(2,0);
			nextBox.graphics.moveTo(10,0);
			nextBox.graphics.lineTo(nextBox.list[nextBox.list.length - 1].x + 10, 0);*/
			//parentFold = Quest.instance.parentFold;
			//Quest.instance.parentFold = this;

			if (next.length > 1){
				fold = UIFactory.createEmbedButton('VToolOrangeButtonBg', VSkin.STRETCH, new VLabel('+'),{vCenter:0, hCenter:0});
				fold.setLayout({w:20, h:20});
				fold.addClickListener(clickFold);
				nextBox.visible = !folded;
				btBox.removeAll(false);
				btBox.addList([fold, button]);
			}
		}

		private function sortfunc(a:QuestView, b:QuestView):int {
			if (a.data.nextQ.length > b.data.nextQ.length)
				return -1;
			if (a.data.nextQ.length < b.data.nextQ.length)
				return 1;
			return 0;
		}
	}
}
