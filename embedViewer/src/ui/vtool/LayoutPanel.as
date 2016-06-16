package ui.vtool {
	import flash.events.MouseEvent;
	import flash.geom.Point;

	import ui.vbase.VComponent;

	public class LayoutPanel extends VComponent {
		private const
			leftAnchor:VComponent = new VComponent(),
			rightAnchor:VComponent = new VComponent(),
			topAnchor:VComponent = new VComponent(),
			bottomAnchor:VComponent = new VComponent(),
			curPos:Point = new Point()
			;
		private var
			trackComponent:VComponent,
			type:uint
			;

		public function LayoutPanel() {
			const s:uint = 6;
			const half_s:uint = s >> 1;

			drawAnchor(leftAnchor, s);
			drawAnchor(rightAnchor, s);
			drawAnchor(bottomAnchor, s);
			drawAnchor(topAnchor, s);

			add(leftAnchor, { left:-half_s, vCenter:0 });
			add(rightAnchor, { right:-half_s, vCenter:0 });
			add(topAnchor, { top:-half_s, hCenter:0 });
			add(bottomAnchor, { bottom:-half_s, hCenter:0 });

			addListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		}

		private function drawAnchor(component:VComponent, size:uint):void {
			component.buttonMode = true;
			component.setSize(size, size);
			component.graphics.beginFill(0, 0);
			component.graphics.drawRect(-1, -1, size + 2, size + 2);
			component.graphics.beginFill(0xFF0000);
			component.graphics.drawRect(0, 0, size, size);
		}

		public function assign(component:VComponent):void {
			trackComponent = component;
			visible = trackComponent != null;
			onStageMouseUp(null);
			if (component) {
				updateGeometry();
			}
		}

		public function updateGeometry():void {
			setGeometrySize(trackComponent.w, trackComponent.h, false);
			var p:Point = trackComponent.localToGlobal(new Point());
			x = p.x;
			y = p.y;
		}

		override public function dispose():void {
			trackComponent = null;
			onStageMouseUp(null);
			super.dispose();
		}

		override protected function customUpdate():void {
			graphics.clear();
			graphics.beginFill(0, 0);
			graphics.lineStyle(1, 0xFF0000);
			graphics.drawRect(0, 0, w, h);
			
			super.customUpdate();
		}
		
		private function onMouseDown(event:MouseEvent):void {
			curPos.x = event.stageX;
			curPos.y = event.stageY;
			if (event.target == topAnchor) {
				type = 1;
			} else if (event.target == bottomAnchor) {
				type = 2;
			} else if (event.target == leftAnchor) {
				type = 3;
			} else if (event.target == rightAnchor) {
				type = 4;
			} else {
				type = 0;
			}
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
		}
		
		private function onStageMouseMove(event:MouseEvent):void {
			var deltaX:Number = event.stageX - curPos.x;
			var deltaY:Number = event.stageY - curPos.y;
			if (deltaX != 0 || deltaY != 0) {
				switch (type) {
					case 1:
						type12(deltaX, deltaY, false);
						break;

					case 2:
						type12(deltaX, deltaY, true);
						break;

					case 3:
						type34(deltaX, deltaY, false);
						break;

					case 4:
						type34(deltaX, deltaY, true);
						break;

					default:
						type0(deltaX, deltaY);
				}

				curPos.x = event.stageX;
				curPos.y = event.stageY;
				VToolPanel.instance.componentPanel.changeComponentLayout();
				updateGeometry();
			}
		}
		
		private function onStageMouseUp(event:MouseEvent):void {
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
		}

		private function type0(deltaX:Number, deltaY:Number):void {
			var empty:int = VComponent.EMPTY;
			if (deltaX != 0) {
				if (trackComponent.hCenter != empty) {
					trackComponent.hCenter += deltaX;
				} else {
					var isLeft:Boolean = trackComponent.left != empty;
					var isRight:Boolean = trackComponent.right != empty;
					if (isLeft || isRight) {
						if (isLeft && isRight) {
							trackComponent.left += deltaX;
							trackComponent.right -= deltaX;
						} else if (isRight) {
							trackComponent.right -= deltaX;
						} else {
							trackComponent.left += deltaX;
						}
					}
				}
			}

			if (deltaY != 0) {
				if (trackComponent.vCenter != empty) {
					trackComponent.vCenter += deltaY;
				} else {
					var isTop:Boolean = trackComponent.top != empty;
					var isBottom:Boolean = trackComponent.bottom != empty;
					if (isTop || isBottom) {
						if (isTop && isBottom) {
							trackComponent.top += deltaY;
							trackComponent.bottom -= deltaY;
						} else if (isBottom) {
							trackComponent.bottom -= deltaY;
						} else {
							trackComponent.top += deltaY;
						}
					}
				}
			}
		}

		private function type12(deltaX:Number, deltaY:Number, isBottom:Boolean):void {
			if (deltaY == 0) {
				return;
			}

			var empty:int = VComponent.EMPTY;
			if (trackComponent.vCenter != empty) {
				if (trackComponent.layoutH >= 0) {
					if (isBottom) {
						deltaY *= -1;
					}
					if (trackComponent.layoutH > 0) {
						var h:Number = trackComponent.layoutH - deltaY;
					} else {
						h = trackComponent.h - deltaY;
					}
					trackComponent.layoutH = h < 1 ? 1 : h;
				}
			} else {
				if (isBottom) {
					if (trackComponent.bottom != empty) {
						trackComponent.bottom -= deltaY;
					} else if (trackComponent.layoutH > 0) {
						trackComponent.layoutH += deltaY;
					}
				} else {
					if (trackComponent.top != empty) {
						trackComponent.top += deltaY;
					} else {
						trackComponent.top = trackComponent.y;
					}
				}
			}
		}

		private function type34(deltaX:Number, deltaY:Number, isRight:Boolean):void {
			if (deltaX == 0) {
				return;
			}

			var empty:int = VComponent.EMPTY;
			if (trackComponent.hCenter != empty) {
				if (trackComponent.layoutW >= 0) {
					if (isRight) {
						deltaX *= -1;
					}
					if (trackComponent.layoutW > 0) {
						var w:Number = trackComponent.layoutW - deltaX;
					} else {
						w = trackComponent.w - deltaX;
					}
					trackComponent.layoutW = w < 1 ? 1 : w;
				}
			} else {
				if (isRight) {
					if (trackComponent.right != empty) {
						trackComponent.right -= deltaX;
					} else if (trackComponent.layoutW > 0) {
						trackComponent.layoutW += deltaX;
					}
				} else {
					if (trackComponent.left != empty) {
						trackComponent.left += deltaX;
					} else {
						trackComponent.left = trackComponent.x;
					}
				}
			}
		}
		
	} //end class
}