package ui.vtool {
	import flash.events.MouseEvent;
	import flash.system.System;

	import ui.vbase.GridControl;
	import ui.vbase.VBox;
	import ui.vbase.VButton;
	import ui.vbase.VCheckbox;
	import ui.vbase.VComponent;
	import ui.vbase.VEvent;
	import ui.vbase.VGrid;
	import ui.vbase.VOComponentItem;
	import ui.vbase.VScrollBar;
	import ui.vbase.VText;

	public class ComponentPanel extends VComponent {
		public static var target:VComponent;
		private const grid:VGrid = new VGrid(1, 7, ComponentRenderer, null, 0, 2, VGrid.H_STRETCH | VGrid.FLOAT_INDEX);
		private var
			curTarget:VComponent,
			regionCb:VCheckbox,
			infoText:VText = new VText(null, 0, 0x591100, 12),
			layoutCb:VCheckbox
			;

		public function ComponentPanel() {
			var style:String = '<p color="0x591100" fontFamily="Myriad Pro" fontSize="12">';
			regionCb = VToolPanel.createCheckbox(style + 'Rect</p>', true);
			var tenCb:VCheckbox = VToolPanel.createCheckbox(style + '10</p>', ComponentRenderer.digitBtValue == 10);
			layoutCb = VToolPanel.createCheckbox(style + 'Edit</p>');

			regionCb.addListener(VEvent.CHANGE, onRegion);
			layoutCb.addListener(VEvent.CHANGE, onLayoutPanel);
			tenCb.addListener(VEvent.CHANGE, onChangeDigitBtValue);

			var copyBt:VButton = VToolPanel.createTextButton('lcp', onCopy);
			copyBt.setSize(38, 18);
			addChild(new VBox(new <VComponent>[regionCb, layoutCb, tenCb, copyBt], 6));
			infoText.format.fontFamily = 'Myriad Pro';
			add(infoText, { left:2, right:2, top:20 });

			var scroll:VScrollBar = VToolPanel.createScrollBar();
			grid.layoutW = scroll.layoutH = -100;
			add(new VBox(new <VComponent>[grid, scroll], 2), { wP:100, top:38 });
			(new GridControl(grid)).assignScrollBar(scroll);
			
			grid.addListener(VEvent.SELECT, onSelect);
		}

		private function assignRegion():void {
			if (regionCb.checked) {
				onRegion();
			} else if (layoutCb.checked) {
				onLayoutPanel();
			}
		}
		
		public function update(key:String = null, isForceRegion:Boolean = false):void {
			if (curTarget == target) {
				if (isForceRegion) {
					assignRegion();
				}
				if (!key) {
					return;
				}
				var index:uint = grid.index;
			} else {
				index = 0;
				curTarget = target;
				updateInfo();
				assignRegion();
			}

			var empty:int = VComponent.EMPTY;
			var dpList:Array = [
				new VOComponentItem('left', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, curTarget.leftOrZero, curTarget.left != empty),
				new VOComponentItem('top', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, curTarget.topOrZero, curTarget.top != empty),
				new VOComponentItem('right', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, curTarget.rightOrZero, curTarget.right != empty),
				new VOComponentItem('bottom', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, curTarget.bottomOrZero, curTarget.bottom != empty),
				new VOComponentItem('layoutW', VOComponentItem.DIGIT, curTarget.layoutW),
				new VOComponentItem('layoutH', VOComponentItem.DIGIT, curTarget.layoutH),
				new VOComponentItem('hCenter', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, curTarget.hCenter == empty ? 0 : curTarget.hCenter, curTarget.hCenter != empty),
				new VOComponentItem('vCenter', VOComponentItem.DIGIT | VOComponentItem.CHECKBOX, curTarget.vCenter == empty ? 0 : curTarget.vCenter, curTarget.vCenter != empty)
			];
			CONFIG::debug {
				var len:uint = dpList.length;
				target.getToolPropList(dpList);
				if (len != dpList.length) {
					for (var i:uint = dpList.length - 1; i >= len; i--) {
						dpList[i].mode |= VOComponentItem.SPEC;
					}
				}
			}

			dpList.push(
				new VOComponentItem('minW', VOComponentItem.DIGIT, curTarget.minW),
				new VOComponentItem('minH', VOComponentItem.DIGIT, curTarget.minH),
				new VOComponentItem('maxW', VOComponentItem.DIGIT, curTarget.maxW),
				new VOComponentItem('maxH', VOComponentItem.DIGIT, curTarget.maxH)
			);

			grid.setDataProvider(dpList, index);

			if (key) {
				for each (var renderer:ComponentRenderer in grid.renderList) {
					if (key == renderer.item.key) {
						renderer.setSelection();
						break;
					}
				}
			}
		}

		private function onSelect(event:VEvent):void {
			var item:VOComponentItem = event.data as VOComponentItem;

			if ((item.mode & VOComponentItem.SPEC) == 0) {
				const empty:int = VComponent.EMPTY;
				switch (item.key) {
					case 'left':
					case 'right':
					case 'top':
					case 'bottom':
					case 'vCenter':
					case 'hCenter':
						curTarget[item.key] = item.checkbox ? item.getInt(-1000, 1000) : empty;
						break;

					case 'layoutW':
					case 'layoutH':
						curTarget[item.key] = item.getInt(-1000, 1000);
						break;

					case 'minW':
					case 'minH':
					case 'maxW':
					case 'maxH':
						curTarget[item.key] = item.valueInt;
						break;

					default:
						var isSkipLayout:Boolean = true;

				} //end switch
				if (!isSkipLayout) {
					if (curTarget.parent is VComponent) {
						curTarget.syncLayout();
					} else {
						curTarget.geometryPhase();
					}
				}
			} else {
				CONFIG::debug {
					curTarget.updateToolProp(item);
				}
			}
			
			updateInfo();
			if (regionCb.checked) {
				onRegion();
			} else if (layoutCb.checked) {
				VToolPanel.instance.layoutPanel.updateGeometry();
			}
			//if (isSyncProperty) {
			//	scrollConnector.getGrid().sync();
			//}
		}
		
		private function updateInfo():void {
			var str:String = curTarget.w + 'x' + curTarget.h + ' (' + curTarget.x + ',' + curTarget.y + ')';
			if (curTarget is VBox) {
				str += ' len=' + (curTarget as VBox).list.length;
			}
			infoText.value = str;
		}
		
		private function onRegion(event:VEvent = null):void {
			if (event && regionCb.checked) {
				layoutCb.checked = false;
				onLayoutPanel();
			}
			if (regionCb.checked) {
				VToolPanel.drawCounter(null, true);
			} else {
				VToolPanel.clearCounter();
			}
		}

		private function onLayoutPanel(event:VEvent = null):void {
			if (event && layoutCb.checked) {
				regionCb.checked = false;
				onRegion();
			}

			if (layoutCb.checked) {
				if (curTarget) {
					VToolPanel.instance.layoutPanel.assign(curTarget);
				}
			} else {
				VToolPanel.instance.layoutPanel.assign(null);
			}
		}

		public function changeComponentLayout():void {
			if (curTarget.parent is VComponent) {
				curTarget.syncLayout();
			} else {
				curTarget.geometryPhase();
			}
			update('left');
			updateInfo();
		}
		
		/**
		 * Обработчик изменения режима ввода числовых значний через кнопки
		 * 
		 * @param	event		Объект события VEvent.CHANGE (cbTen)
		 */
		private function onChangeDigitBtValue(event:VEvent):void {
			ComponentRenderer.digitBtValue = event.data ? 10 : 1;
		}

		private function onCopy(event:MouseEvent):void {
			if (!curTarget) {
				return;
			}
			const list:Vector.<String> = new Vector.<String>();
			const empty:int = VComponent.EMPTY;

			if (curTarget.left != empty) {
				list.push('left:' + curTarget.left);
			}
			if (curTarget.right != empty) {
				list.push('right:' + curTarget.right);
			}
			if (curTarget.top != empty) {
				list.push('top:' + curTarget.top);
			}
			if (curTarget.bottom != empty) {
				list.push('bottom:' + curTarget.bottom);
			}
			if (curTarget.hCenter != empty) {
				list.push('hCenter:' + curTarget.hCenter);
			}
			if (curTarget.vCenter != empty) {
				list.push('vCenter:' + curTarget.vCenter);
			}

			if (curTarget.layoutW != 0) {
				if (curTarget.layoutW < 0) {
					list.push('wP:' + (-curTarget.layoutW));
				} else {
					list.push('w:' + curTarget.layoutW);
				}
			}
			if (curTarget.layoutH != 0) {
				if (curTarget.layoutH < 0) {
					list.push('hP:' + (-curTarget.layoutH));
				} else {
					list.push('h:' + curTarget.layoutH);
				}
			}

			if (curTarget.minW > 0) {
				list.push('minW:' + curTarget.minW);
			}
			if (curTarget.maxW > 0) {
				list.push('maxW:' + curTarget.maxW);
			}
			if (curTarget.minH > 0) {
				list.push('minH:' + curTarget.minH);
			}
			if (curTarget.maxH > 0) {
				list.push('maxH:' + curTarget.maxH);
			}

			System.setClipboard('{ ' + list.join(', ') + ' }');
		}

		/*
		private function syncInputText(key:String, value:String):void {
			for each (var renderer:ComponentRenderer in scrollConnector.getGridPanel().renders) {
				if (renderer.item.key == key) {
					renderer.setInputText(value);
					break;
				}
			}
		}
		*/
		
	} //end class
}