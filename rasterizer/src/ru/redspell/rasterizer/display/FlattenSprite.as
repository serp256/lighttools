package ru.redspell.rasterizer.display {
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.filters.BitmapFilter;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	public class FlattenSprite extends Sprite implements IFlatten {
        public static const BMP_SMOOTHING_MISTAKE:Number = 0;

		protected var _childs:Vector.<FlattenImage> = new Vector.<FlattenImage>();
        protected var _masks:Object = {};
        protected var _masked:Dictionary = new Dictionary();

        protected function applyFilters(obj:FlattenImage, fltrs:Array):FlattenImage {
            var finalRect:Rectangle = new Rectangle(0, 0, obj.width, obj.height);
            var m:Matrix = obj.matrix;

            for each (var fltr:BitmapFilter in fltrs) {
                var srcRect:Rectangle = new Rectangle(0, 0, obj.width, obj.height);
                var fltrRect:Rectangle = obj.generateFilterRect(srcRect, fltr);
                var fltrLayer:FlattenImage = new FlattenImage(fltrRect.width, fltrRect.height, true, 0x00000000);

                finalRect = finalRect.union(fltrRect);
                fltrLayer.applyFilter(obj, srcRect, new Point(0, 0), fltr);
                obj.dispose();
                obj = fltrLayer;
            }

            //m.translate(finalRect.x, finalRect.y);
            obj.matrix = m;

            return obj;
        }

        protected function getTransformedBounds(rect:Rectangle, mtx:Matrix):Rectangle {
            var pnts:Vector.<Point> = new Vector.<Point>();

            pnts.push(mtx.transformPoint(new Point(rect.x, rect.y)));
            pnts.push(mtx.transformPoint(new Point(rect.x + rect.width, rect.y)));
            pnts.push(mtx.transformPoint(new Point(rect.x + rect.width, rect.y + rect.height)));
            pnts.push(mtx.transformPoint(new Point(rect.x, rect.y + rect.height)));

            var lt:Point = new Point(Number.MAX_VALUE, Number.MAX_VALUE);
            var rb:Point = new Point(-Number.MAX_VALUE, -Number.MAX_VALUE);

			trace(lt + ' ' + rb);
			trace(Number.MIN_VALUE);

            for each (var pnt:Point in pnts) {
                lt.x = Math.min(lt.x, pnt.x);
                lt.y = Math.min(lt.y, pnt.y);
                rb.x = Math.max(rb.x, pnt.x);
                rb.y = Math.max(rb.y, pnt.y);
            }

            var retval:Rectangle = new Rectangle(lt.x, lt.y, rb.x - lt.x, rb.y - lt.y);

            if (retval.width < 0) {
                retval.x += retval.width;
                retval.width *= -1;
            }

            if (retval.height < 0) {
                retval.y += retval.height;
                retval.height *= -1;
            }

            return retval;
        }

        protected function applyMatrix(obj:DisplayObject, mtx:Matrix, color:ColorTransform):FlattenImage {
            var rect:Rectangle = getTransformedBounds(obj.getRect(obj), mtx);
            var objBmpData:FlattenImage = new FlattenImage(Math.ceil(rect.width) + BMP_SMOOTHING_MISTAKE, Math.ceil(rect.height) + BMP_SMOOTHING_MISTAKE, true, 0x00000000);
            var m:Matrix = mtx.clone();

            m.translate(-rect.x, -rect.y);
            objBmpData.draw(obj, m, color, null, null, true);
            objBmpData.matrix = new Matrix(1, 0, 0, 1, rect.x, rect.y);
            objBmpData.name = obj.name;

            return objBmpData;
        }

        protected function applyMasks():void {
            for (var m:Object in _masked) {
                var masked:FlattenImage = m as FlattenImage;
                var mask:FlattenImage = _masks[_masked[masked]];

                var maskedRect:Rectangle = new Rectangle(masked.matrix.tx, masked.matrix.ty, masked.width, masked.height);
                var maskRect:Rectangle = new Rectangle(mask.matrix.tx, mask.matrix.ty, mask.width, mask.height);
                var intersect:Rectangle = maskedRect.intersection(maskRect);

                var srcRect:Rectangle = new Rectangle(intersect.x - maskRect.x, intersect.y - maskRect.y, intersect.width, intersect.height);
                var dstPnt:Point = new Point(intersect.x - maskedRect.x, intersect.y - maskedRect.y);

                masked.threshold(mask, srcRect, dstPnt, '==', 0x00000000, 0x00000000, 0xff000000);

                var maskedFinal:FlattenImage = new FlattenImage(intersect.width, intersect.height, true, 0x00000000);

                maskedFinal.copyPixels(masked, new Rectangle(dstPnt.x, dstPnt.y, intersect.width, intersect.height), new Point(0, 0));

                _childs.splice(_childs.indexOf(mask), 1);
				_childs.splice(_childs.indexOf(masked), 1, maskedFinal);
                mask.dispose();
                masked.dispose();

                maskedFinal.matrix = new Matrix(1, 0, 0, 1, intersect.x, intersect.y);
            }
        }

        protected function cleanMasks():void {
            _masks = {};
            _masked = new Dictionary();
        }

        protected function flatten(obj:DisplayObject, matrix:Matrix = null, color:ColorTransform = null, filters:Array = null):void {
            if (matrix == null) {
                matrix = new Matrix();
            }

            if (color == null) {
                color = new ColorTransform();
            }

            if (filters == null) {
                filters = [];
            }

            var container:DisplayObjectContainer = obj as DisplayObjectContainer;
            var clr:ColorTransform = new ColorTransform(color.redMultiplier, color.greenMultiplier, color.blueMultiplier, color.alphaMultiplier, color.redOffset, color.greenOffset, color.blueOffset, color.alphaOffset);

            clr.concat(obj.transform.colorTransform);

            if (container) {
                var mtx:Matrix = obj.transform.matrix.clone();
                var fltrs:Array = filters.concat(obj.filters);

                mtx.concat(matrix);

                for (var i:uint = 0; i < container.numChildren; i++) {
                    flatten(container.getChildAt(i), mtx, clr, fltrs);
                }
            } else {
                mtx = matrix.clone();
                mtx.concat(obj.transform.matrix);

                var layer:FlattenImage = applyFilters(applyMatrix(obj, mtx, clr), filters);
                _childs.push(layer);

                var matches:Array = obj.parent.name.match(/^(masked|mask)([\d]+)$/);

                if (!matches) {
                    return;
                }

                if (matches[1] == 'masked') {
                    _masked[layer] = matches[2];
                } else {
                    _masks[matches[2]] = layer;
                }
            }
        }

        public function fromDisplayObject(obj:DisplayObject):IFlatten {
            cleanMasks();
            flatten(obj);
            applyMasks();

            return this;
        }

		public function get childs():Vector.<FlattenImage> {
			return _childs;
		}

		public function dispose():void {
			for each (var child:FlattenImage in _childs) {
				child.dispose();
			}
		}
	}
}