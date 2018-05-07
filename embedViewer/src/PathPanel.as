package {
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.filesystem.File;
	import flash.net.SharedObject;

	import ui.vbase.VBox;
	import ui.vbase.VButton;
	import ui.vbase.VComponent;
	import ui.vbase.VEvent;
	import ui.vbase.VGrid;
	import ui.vbase.VText;
	import ui.vtool.VToolPanel;

	public class PathPanel extends VComponent {
		private var
			cookie:SharedObject,
			errorText:VText
			;

		public function PathPanel() {
			var browseBt:VButton = VToolPanel.createTextButton('browse');
			browseBt.addClickListener(onBrowse);
			var box:VBox = new VBox(new <VComponent>[
				new VText('Укажите каталог с swf/swc-файлами\n(будут отображены классы из пакетов eSkins/Skins)', VText.CENTER),
				browseBt
			], 10, VBox.VERTICAL);
			add(box, { hCenter:0, vCenter:0 });

			try {
				cookie = SharedObject.getLocal('EmbedViewer');
				cookie.addEventListener(NetStatusEvent.NET_STATUS, onNetStatusHandler);
			} catch (error:Error) {
			}

			var str:String = String(getCookieData('pathList', ''));
			if (str && str.length > 0) {
				box.add(new VText('Последние:'));
				var dp:Array = str.split(';');
				var grid:VGrid = new VGrid(1, dp.length > 10 ? 10 : dp.length, PathItemRenderer, dp, 0, 3, VGrid.H_STRETCH);
				grid.layoutW = 500;
				grid.addEventListener(VEvent.VARIANCE, onVariance);
				box.add(grid);
				var clearBt:VButton = VToolPanel.createTextButton('clear', onHistoryClear, 'Orange');
				clearBt.data = box;
				box.add(clearBt);
			}
		}

		private function onBrowse(event:MouseEvent):void {
			var f:File = File.desktopDirectory;
			f.addEventListener(Event.SELECT, onDirectorySelected);
			f.browseForDirectory('Укажите каталог с swf/swc-файлами');
		}

		private function onDirectorySelected(event:Object):void {
			clearError();
			try {
				var f:File = event is Event ? (event as Event).target as File : new File(event as String);
				if (f.exists && f.isDirectory) {
					//переход в режим отображения скинов
					ViewerMain.instance.showViewer(f);
					//сохраняем в cookie
					var str:String = String(getCookieData('pathList', ''));
					if (str && str.length > 0) {
						var ar:Array = str.split(';');
						if (ar.indexOf(f.nativePath) < 0) {
							ar.unshift(f.nativePath);
							const max:uint = 6;
							if (ar.length > max) {
								ar.length = max;
							}
							str = ar.join(';')
						} else {
							return;
						}
					} else {
						str = f.nativePath;
					}
					setCookieData('pathList', str);
				} else {
					showError('Path exists=' + f.exists + ', isDirectory=' + f.isDirectory);
				}
			} catch (error:Error) {
				showError('Path: ' + error);
			}
		}

		private function onNetStatusHandler(event:NetStatusEvent):void {
		}

		/**
		 * Установить данные Cookie
		 *
		 * @param	name		Имя определяемой переменной
		 * @param	value		Значение
		 * @param	isFlush		Сразу сохранить на диске
		 */
		public function setCookieData(name:String, value:*, isFlush:Boolean = true):void {
			if (cookie) {
				cookie.data[name] = value;
				if (isFlush) {
					try {
						cookie.flush();
					} catch (error:Error) {
					}
				}
			}
		}

		/**
		 * Получить данные Cookie
		 *
		 * @param	name			Имя переменной
		 * @param	defaultValue	Возвращаемое значение, если переменная не определена
		 * @return
		 */
		public function getCookieData(name:String, defaultValue:* = null):* {
			return (cookie && cookie.data.hasOwnProperty(name)) ? cookie.data[name] : defaultValue;
		}

		private function onVariance(event:VEvent):void {
			onDirectorySelected(event.data);
		}

		private function showError(value:String):void {
			if (!errorText) {
				errorText = new VText(value, VText.CENTER, 0xFF0000, 16);
				add(errorText, { left:30, right:30, top:30 });
			} else {
				errorText.value = value;
			}
		}

		private function clearError():void {
			if (errorText) {
				remove(errorText);
				errorText = null;
			}
		}

		private function onHistoryClear(event:MouseEvent):void {
			setCookieData('pathList', '');
			var box:VBox = (event.currentTarget as VButton).data as VBox;
			while (box.list.length > 2) {
				box.removeAt(box.list.length - 1);
			}
		}

	} //end class
}