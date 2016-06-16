package {
	import deng.fzip.FZipFile;

	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.filters.GlowFilter;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;

	import ui.vbase.GridControl;
	import ui.vbase.SkinManager;
	import ui.vbase.VBox;
	import ui.vbase.VButton;
	import ui.vbase.VCheckbox;
	import ui.vbase.VComponent;
	import ui.vbase.VEvent;
	import ui.vbase.VGrid;
	import ui.vbase.VInputText;
	import ui.vbase.VPager;
	import ui.vbase.VSkin;
	import ui.vbase.VText;
	import ui.vtool.VToolPanel;

	public class ViewerPanel extends VComponent {
		private const
			grid:VGrid = new VGrid(4, 3, SkinItemRenderer, [], 25, 25, VGrid.FILTER_MODE),
			countText:VText = new VText(),
			kindInput:VInputText = VToolPanel.createInputText(14, 0),
			fileInput:VInputText = VToolPanel.createInputText(14, 0)
			;

		public function ViewerPanel() {
			add(grid, { hCenter:0, top:70 });
			grid.addListener(VEvent.CHANGE, onGridChange);

			var connector:GridControl = new GridControl(grid, GridControl.NAV_BT_VISIBLE | GridControl.PAGER_CALC_COUNT);
			var pager:VPager = createPager(20);
			add(pager, { bottom:30, hCenter:0 });

			var prevBt:VButton = createNavButton(false, false);
			add(prevBt, { vCenter:0, left:30, w:43, h:70 });
			var nextBt:VButton = createNavButton(true, false);
			add(nextBt, { vCenter:0, right:30, w:43, h:70 });
			connector.assignNavButtons(prevBt, nextBt);
			connector.assignPager(pager);
			add(countText, { hCenter:0, bottom:72 });

			var cb:VCheckbox = VToolPanel.createCheckbox('Blue glow');
			cb.addListener(VEvent.CHANGE, onGlow);
			add(cb, { top:20, right:20 });

			var bt:VButton = VToolPanel.createTextButton('clear', onFilterClear);
			fileInput.layoutW = kindInput.layoutW = 250;
			kindInput.addListener(VEvent.CHANGE, onFilter);
			fileInput.addListener(VEvent.CHANGE, onFilter);
			add(new VBox(new <VComponent>[
			    new VText('kind filter:'), kindInput, new VText('filename filter:'), fileInput, bt
			]), { left:20, top:12 });

			bt = VToolPanel.createTextButton('back', onBack, 'Orange');
			add(bt, { left:10, bottom:10 });
		}

		public function init(file:File):void {
			if (!file.exists && !file.isDirectory) {
				throw new Error('bad swf/swc-directory');
			}

			const fs:FileStream = new FileStream();
			for each (var inFile:File in file.getDirectoryListing()) {
				if (inFile.isDirectory || inFile.isHidden || inFile.isSymbolicLink || inFile.isPackage) {
					continue;
				}
				var ext:String = inFile.extension;
				if (!ext) {
					continue;
				}
				ext = ext.toLowerCase();
				if (ext != 'swf' && ext != 'swc') {
					continue;
				}

				fs.open(inFile, FileMode.READ);
				var ba:ByteArray = new ByteArray();
				fs.readBytes(ba);
				fs.close();

				if (ext == 'swf') {
					loadSwf(ba, inFile.name);
				} else {
					loadSwc(ba, inFile.name);
				}
			}
		}

		private function removeLoaderListener(loaderInfo:LoaderInfo):void {
			loaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onError);
			loaderInfo.removeEventListener(Event.COMPLETE, onComplete);
		}

		private function loadSwf(ba:ByteArray, name:String):void {
			var loader:Loader = new Loader();
			loader.name = name;
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onError);
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
			//храним классы в разных доменах
			var context:LoaderContext = new LoaderContext();
			context.allowCodeImport = true;
			context.applicationDomain = new ApplicationDomain();
			try {
				loader.loadBytes(ba, context);
			} catch (error:Error) {
				trace('error: ' + error);
				removeLoaderListener(loader.contentLoaderInfo);
			}
		}

		private function loadSwc(ba:ByteArray, name:String):void {
			var zip:MyFZip = new MyFZip();
			zip.name = name;
			zip.addEventListener(Event.COMPLETE, onZip);
			try {
				zip.loadBytes(ba);
			} catch (error:Error) {
			}
		}

		private function onZip(event:Event):void {
			var zip:MyFZip = event.currentTarget as MyFZip;
			for (var i:int = zip.getFileCount() - 1; i >= 0; i--) {
				var file:FZipFile = zip.getFileAt(i);
				if (file.filename.indexOf('.swf') > 0) {
					loadSwf(file.content, zip.name);
				}
			}
		}

		private function onError(event:IOErrorEvent):void {
		}

		private function onComplete(event:Event):void {
			const loaderInfo:LoaderInfo = event.currentTarget as LoaderInfo;
			removeLoaderListener(loaderInfo);
			const dp:Array = grid.getDataProvider();
			for each (var kind:String in loaderInfo.applicationDomain.getQualifiedDefinitionNames()) {
				if (kind.indexOf('ESkins::') != 0 && kind.indexOf('Skins::') != 0) {
					continue;
				}
				var item:VOSkin = new VOSkin();
				item.kind = kind;
				item.kindLower = kind.toLowerCase();
				item.loaderInfo = loaderInfo;
				item.filenameLower = loaderInfo.loader.name.toLowerCase();
				dp.push(item);
			}
			dp.sortOn('kind');
			grid.sync();
		}

		private function onGlow(event:VEvent):void {
			var filterList:Array = event.data ? [new GlowFilter(0x0000FF, 1, 4, 4, 2)] : null;
			for each (var itemRenderer:SkinItemRenderer in grid.renderList) {
				itemRenderer.container.filters = filterList;
			}
		}

		private function onGridChange(event:VEvent):void {
			var m:uint = grid.index + grid.maxRenderer;
			if (m > grid.length) {
				m = grid.length;
			}
			countText.value = (grid.index + 1) + '..' + m +  '/' + grid.length;
		}

		private function onFilterClear(event:MouseEvent):void {
			kindInput.value = null;
			fileInput.value = null;
			onFilter(null);
		}

		private function onFilter(event:VEvent):void {
			var kindFilter:String = kindInput.value;
			var isKind:Boolean = Boolean(kindFilter);
			if (isKind) {
				kindFilter = kindFilter.toLowerCase()
			}
			var fileFilter:String = fileInput.value;
			var isFile:Boolean = Boolean(fileFilter);
			if (isFile) {
				fileFilter = fileFilter.toLowerCase();
			}
			for each (var item:VOSkin in grid.getDataProvider()) {
				item.isFilterHide = (isKind && item.kindLower.indexOf(kindFilter) < 0) || (isFile && item.filenameLower.indexOf(fileFilter) < 0);
			}
			grid.sync();
		}

		private function onBack(event:MouseEvent):void {
			ViewerMain.instance.showPath();
		}

		private function createNavButton(isRightOrBottom:Boolean, isVertical:Boolean = false, mode:uint = 0, skinName:String = 'NavBt'):VButton {
			if (isVertical) {
				mode |= VSkin.ROTATE_90;
				if (isRightOrBottom) {
					mode |= VSkin.FLIP_Y;
				}
			} else {
				if (isRightOrBottom) {
					mode |= VSkin.FLIP_X;
				}
			}
			return VButton.createEmbed(skinName, mode);
		}

		private function createPager(showCountLimit:uint = 16):VPager {
			var bg:VSkin = SkinManager.getEmbed('PagerBg', VSkin.STRETCH);
			bg.assignLayout({ left:-16, right:-16, top:1 });
			var pager:VPager = new VPager('PagerOnBt', 'PagerOffBt', 6, 1, bg);
			pager.showCountLimit = showCountLimit;
			pager.layoutH = bg.measuredHeight;
			return pager;
		}

	} //end class
}