package ru.redspell.rasterizer.flatten {
	import com.codeazur.as3swf.SWF;
	import com.codeazur.as3swf.SWFTimelineContainer;
	import com.codeazur.as3swf.tags.IDefinitionTag;
	import com.codeazur.as3swf.tags.ITag;
	import com.codeazur.as3swf.tags.TagDefineSprite;
	import com.codeazur.as3swf.tags.TagEnd;
	import com.codeazur.as3swf.tags.TagFrameLabel;
	import com.codeazur.as3swf.tags.TagPlaceObject;
	import com.codeazur.as3swf.tags.TagPlaceObject2;
	import com.codeazur.as3swf.tags.TagPlaceObject3;
	import com.codeazur.as3swf.tags.TagPlaceObject4;
	import com.codeazur.as3swf.tags.TagRemoveObject;
	import com.codeazur.as3swf.tags.TagRemoveObject2;
	import com.codeazur.as3swf.tags.TagShowFrame;
	import com.codeazur.as3swf.tags.TagSoundStreamHead;
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.filters.BitmapFilter;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	import ru.redspell.rasterizer.flatten.FlattenImage;
	import ru.redspell.rasterizer.models.Swf;
	import ru.redspell.rasterizer.models.SwfClass;





	public class FlattenSprite extends Sprite implements IFlatten {
        public static const BMP_SMOOTHING_MISTAKE:Number = 0;

		protected var _scale:Number = 1;
		public var label:String = '';

		protected var _childs:Vector.<IFlatten> = new Vector.<IFlatten>();
        protected var _masks:Object = {};
        protected var _masked:Dictionary = new Dictionary();
        protected var _namedMasks:Object = {};
        protected var maskForAll:FlattenImage;

        protected function applyFilters(obj:FlattenImage, fltrs:Array):FlattenImage {
            var finalRect:Rectangle = new Rectangle(0, 0, obj.width, obj.height);
            var m:Matrix = obj.matrix;
			var name:String = obj.name;

            for each (var fltr:BitmapFilter in fltrs) {
                //trace('src rect ' + fltrRect);
                var srcRect:Rectangle = new Rectangle(0, 0, obj.width, obj.height);
                var fltrRect:Rectangle = obj.generateFilterRect(srcRect, fltr);
                var fltrLayer:FlattenImage = new FlattenImage(fltrRect.width, fltrRect.height, true, 0x00000000);

                //trace('fltrRect ' + fltrRect);

                finalRect = finalRect.union(fltrRect);
                fltrLayer.applyFilter(obj, srcRect, new Point(-fltrRect.x, -fltrRect.y), fltr);
                obj.dispose();
                obj = fltrLayer;
            }

            m.translate(finalRect.x, finalRect.y);
            obj.matrix = m;
			obj.name = name;

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

            //trace("obj.getRect(obj)", obj.name, obj.getRect(obj));
            //trace("mtx", mtx);
            //trace("rect", rect);
            //trace("Math.ceil(rect.width), Math.ceil(rect.height)", Math.ceil(rect.width), Math.ceil(rect.height));

            //trace("rect " + Math.round(rect.width) + " " + Math.round(rect.height));

            rect.width = Math.round(rect.width);
            rect.width = rect.width < 1 ? 1 : rect.width;

            rect.height = Math.round(rect.height);
            rect.height = rect.height < 1 ? 1 : rect.height;

            var objBmpData:FlattenImage = new FlattenImage(rect.width, rect.height, true, 0x00000000);
            var m:Matrix = mtx.clone();

            m.translate(-rect.x, -rect.y);

            /*var pizda:Matrix = m.clone();
            pizda.concat(obj.transform.matrix);
            obj.transform.matrix = pizda;
            objBmpData.draw(obj, null, color, null, null, true);*/

            objBmpData.drawWithQuality(obj, m, color, null, null, true, flash.display.StageQuality.BEST);

            objBmpData.matrix = new Matrix(1, 0, 0, 1, rect.x, rect.y);
            objBmpData.name = obj.name;

            return objBmpData;
        }

        protected function applyMask(mask:FlattenImage, masked:FlattenImage, disposeMask:Boolean = true):int {
            var maskedRect:Rectangle = new Rectangle(Math.round(masked.matrix.tx), Math.round(masked.matrix.ty), masked.width, masked.height);
            var maskRect:Rectangle = new Rectangle(Math.round(mask.matrix.tx), Math.round(mask.matrix.ty), mask.width, mask.height);
            var intersect:Rectangle = maskedRect.intersection(maskRect);

            if (intersect.isEmpty()) {
                if (disposeMask) {
                    _childs.splice(_childs.indexOf(mask), 1);
                    mask.dispose();
                }
				//trace('EMPTY retval is', retval);
                var retval:int = _childs.indexOf(masked);
                _childs.splice(_childs.indexOf(masked), 1);
                /*
                ??? return it if needed
                _childs.splice(_childs.indexOf(masked), 1);
                masked.dispose();
                */

                return retval;
            }

            var srcRect:Rectangle = new Rectangle(intersect.x - maskRect.x, intersect.y - maskRect.y, intersect.width, intersect.height);
            var dstPnt:Point = new Point(intersect.x - maskedRect.x, intersect.y - maskedRect.y);

            masked.threshold(mask, srcRect, dstPnt, '==', 0x00000000, 0x00000000, 0xff000000);

            var maskedFinal:FlattenImage = new FlattenImage(intersect.width, intersect.height, true, 0x00000000);

            maskedFinal.copyPixels(masked, new Rectangle(dstPnt.x, dstPnt.y, intersect.width, intersect.height), new Point(0, 0));

            if (disposeMask) {
                _childs.splice(_childs.indexOf(mask), 1);
                mask.dispose();
            }

            retval = _childs.indexOf(masked);
			//trace('retval is', retval);
            _childs.splice(retval, 1, maskedFinal);
            masked.dispose();
			//trace('final:', maskedFinal.width, maskedFinal.height, maskedFinal.rect);

            maskedFinal.name = masked.name;
            maskedFinal.matrix = new Matrix(1, 0, 0, 1, intersect.x, intersect.y);

            return retval + 1;
        }
		
        protected function applyMasks():void {
            for (var m:Object in _masked) {
                try {
                    var masked:FlattenImage = m as FlattenImage;
                    var mask:FlattenImage = _masks[_masked[masked]];

                    //trace('mask: ' + mask);
                    //trace('masked: ' + masked);

                    if (mask == null || masked == null) {
                        continue;
                    }

                    applyMask(mask, masked);
                } catch (e:ArgumentError) {
                }
            }


        }

        protected function cleanMasks():void {
            _masks = {};
            _masked = new Dictionary();
        }

        protected function flatten(obj:DisplayObject, matrix:Matrix = null, color:ColorTransform = null, filters:Array = null, name:String = null):void {
			if (!obj) {
				return;
			}
			
			obj.mask = null; //хак, таким образом убиваем маски таймлайна
			
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
                var customName:Boolean = !/^instance[\d]+$/.test(obj.name);

                mtx.concat(matrix);


                if (container.numChildren == 0 && customName) {
                    mtx.scale(_scale, _scale);

                    var box:FlattenSprite = new FlattenSprite();
                    box.name = obj.name;
                    box.transform.matrix = mtx.clone();

                    _childs.push(box);
                } else if (container.numChildren == 1 && customName) {
                    flatten(container.getChildAt(0), mtx, clr, fltrs, container.name);
                } else {
                    for (var i:uint = 0; i < container.numChildren; i++) {
                        flatten(container.getChildAt(i), mtx, clr, fltrs);
                    }
                }
            } else {
                //mtx = matrix.clone();
                //mtx.concat(obj.transform.matrix);

                mtx = obj.transform.matrix.clone();
                mtx.concat(matrix);
				mtx.scale(_scale, _scale);

                //trace('obj', obj.width, obj.height);
                //trace('obj', obj.parent.name, obj.getRect(obj), obj.transform.matrix, matrix, mtx);

                var layer:FlattenImage = applyFilters(applyMatrix(obj, mtx, clr), filters);
                _childs.push(layer);

                if (name != null) {
                    layer.name = name;
                }

                if (obj.parent.name == "maskfor_all") {
                    maskForAll = layer;
                } else {
                    var matches:Array = obj.parent.name.match(/^(masked|mask)([\d]+)$/);

                    if (!matches) {
                        matches = obj.parent.name.match(/^maskfor_(.+)$/);

                        if (!matches) {
                            return;
                        }

                        _namedMasks[matches[1]] = layer;
                    }

                    if (matches[1] == 'masked') {
                        _masked[layer] = matches[2];
                    } else {
                        _masks[matches[2]] = layer;
                    }
                }
            }
        }

		protected function clipTransparency():void {
			var i:uint = 0;

			while (i < _childs.length) {
				var img:FlattenImage = _childs[i] as FlattenImage;

				if (!img) {
					i++;
					continue;
				}

				var rect:Rectangle = img.getColorBoundsRect(0xff000000, 0x00000000, false);

				if (rect.isEmpty()) {
					_childs.splice(i, 1);
					continue;
				}

				var clipped:FlattenImage = new FlattenImage(rect.width, rect.height, true, 0x00000000);

				clipped.copyPixels(img, rect, new Point(0, 0));
				clipped.matrix = img.matrix.clone();
				clipped.matrix.translate(rect.x, rect.y);
				clipped.name = img.name;

				_childs.splice(i++, 1, clipped);
				img.dispose();
			}
		}
		
		public function fromSwfClass(cls:SwfClass, scale:Number):IFlatten {
			swf = cls.root;
			return fromDisplayObject(new cls.definition(), scale, cls.tag);
		}
		
		public function prepareParseTags():void {
			previousList = {};
			clipDepthList = {};
			_tagMasked = new Dictionary();
			_tagMasks = {};
		}
		
		public var swf:SWF;
		public var previousList:Object = {};
		public var clipDepthList:Object = {};
		private var _tagMasked:Dictionary;
        private var _tagMasks:Object;
		
		private function defineTagMasks(flattenTags:Object, flattenClips:Object):void {
			var cnt:uint = 0;
			var indexedList:Array = [];
			
			var indexes:Array = [];
			for (var ind:String in flattenTags) {
				indexes.push(int(ind));
			}
			indexes.sort(Array.NUMERIC);
			if (indexes.length != childs.length) {
				throw new Error('wrong number of childs');
			}
			
			var incremental:uint = 0;
			for (var depth_str:String in flattenClips) {
				var depth:uint = uint(depth_str);
				var clip:uint = flattenClips[depth];
				for (var depth2_str:String in flattenTags) {
					var depth2:uint = uint(depth2_str);
					if (depth2 > depth && depth2 <= clip) {
						_tagMasks[10000 + incremental] = _childs[indexes.indexOf(depth)];
						_tagMasked[_childs[indexes.indexOf(depth2)]] = 10000 + incremental;
						incremental++;
					}
				}
			}
		}
		
		public function parseTags2(root:IDefinitionTag, targetFrameIndex:uint):Array {
			if (!(root is SWFTimelineContainer)) {
				throw new Error('definition tag ' + root.name + ' is not supported!');
			}
			var result:Object = {};
			var clip:Object = {};
			var offsets:Object = {};
			var frameIndex:uint = 0;
			var isEnd:Boolean = false;
			var container:SWFTimelineContainer = root as SWFTimelineContainer;
			for (var i:uint = 0; i < container.tags.length; i++) {
				if (targetFrameIndex == frameIndex) {
					break;
				}
				var tag:ITag = container.tags[i];
				if (isEnd) {
					throw new Error('swf ended too early!');
				} else
				if (tag is TagPlaceObject || tag is TagPlaceObject2 || tag is TagPlaceObject3 || tag is TagPlaceObject4) {
					placeObject(tag as TagPlaceObject, frameIndex, result, clip, offsets);
				} else
				if (tag is TagRemoveObject || tag is TagRemoveObject2) {
					removeObject(tag as TagRemoveObject, result, clip, offsets);
				} else
				if (tag is TagShowFrame) {
					frameIndex++;
				} else
				if (tag is TagEnd) {
					isEnd = true;
				} else
				if (!(tag is TagFrameLabel || tag is TagSoundStreamHead)) {
					throw new Error('inner tag ' + tag.name + ' is not supported!')
				}
			}
			
			var toAdd:Object = {};
			var toRemove:Array = [];
			for (var depth:String in result) {
				var tpo:TagPlaceObject = result[depth] as TagPlaceObject;
				if (tpo == null || !tpo.hasCharacter) {
					throw new Error('fffffffffffff') //по идее невозможно, всегда будет hasCharacter
				}
				var def:IDefinitionTag = Swf.getSwfCharacter(swf, tpo.characterId);
				if (def is SWFTimelineContainer) {
					var res:Array = parseTags2(def, targetFrameIndex - offsets[tpo.depth]);
					var cnt:uint = 0;
					var ind:uint = 0;
					for (var t:Object in res[0]) {
						cnt++;
						ind = uint(t);
						if (cnt > 1) {
							break;
						}
					}
					if (cnt == 1) {
						var def:IDefinitionTag = Swf.getSwfCharacter(swf, ind);
						if (!(def is TagDefineSprite)) {
							continue; //основываясь на теории, что спрайт с одним шейпом занимает 1 глубину, а не 2
						}
					}
					toRemove.push(depth);
					concatTagLayers(toAdd, res[0], tpo.depth);
					concatTagLayers(clip, res[1], tpo.depth);
					for (var index:String in clip) {
						if (index == depth) {
							var nv:String = null;
							for (t in res[0]) {
								nv = String(int(t) + tpo.depth);
								break; //первый индекс берем
							}
							clip[nv] = clip[depth]
							delete clip[depth];
						}
					}
				}
			}
			for each (depth in toRemove) {
				delete result[depth];
			}
			for (depth in toAdd) {
				if (result.hasOwnProperty(depth)) {
					throw new Error('aaaaaaaaaaaaaaa'); //это очень плохо
				} else {
					result[depth] = toAdd[depth];
				}
			}
			
			return [result, clip];
		}
		
		private function placeObject(tpo:TagPlaceObject, currentFrameIndex:uint, result:Object, clip:Object, offsets:Object):void {
			if (!tpo.hasMove && tpo.hasCharacter && !result.hasOwnProperty(tpo.depth)) {
				result[tpo.depth] = tpo;
				offsets[tpo.depth] = currentFrameIndex;
				if (tpo.hasClipDepth) {
					clip[tpo.depth] = tpo.clipDepth;
				}
			} else
			if (tpo.hasMove && !tpo.hasCharacter && result.hasOwnProperty(tpo.depth)) {
				if (tpo.hasClipDepth) {
					throw new Error('TagPlaceObject2 hasMove and hasClipDepth');
				}
			} else
			if (tpo.hasMove && tpo.hasCharacter && result.hasOwnProperty(tpo.depth)) {
				if (offsets.hasOwnProperty(tpo.depth)) {
					delete offsets[tpo.depth];
				}
				if (clip.hasOwnProperty(tpo.depth)) {
					delete clip[tpo.depth];
				}
				delete result[tpo.depth];
				result[tpo.depth] = tpo;
				offsets[tpo.depth] = currentFrameIndex;
				if (tpo.hasClipDepth) {
					clip[tpo.depth] = tpo.clipDepth;
				}
			} else {
				throw new Error(tpo.name + ' has wrong attributes');
			}
		}
		
		private function removeObject(tro:TagRemoveObject, result:Object, clip:Object, offsets:Object):void {
			if (result.hasOwnProperty(tro.depth)) {
				if (offsets.hasOwnProperty(tro.depth)) {
					delete offsets[tro.depth];
				}
				if (clip.hasOwnProperty(tro.depth)) {
					delete clip[tro.depth];
				}
				delete result[tro.depth];
			} else {
				throw new Error(tro.name + ' has wrong attributes');
			}
		}
		
		public function concatTagLayers(target:Object, source:Object, depth:uint):void {
			for (var index:String in source) {
				target[int(index) + depth] = source[index];
			}
		}
		
		public function applyTagMasks():void {
			for (var m:Object in _tagMasked) {
                try {
                    var masked:FlattenImage = m as FlattenImage;
                    var mask:FlattenImage = _tagMasks[_tagMasked[masked]];

                    if (mask == null || masked == null) {
                        continue;
                    }
					//trace('mask:', mask.width, mask.height, mask.rect);
					//trace('masked:', masked.width, masked.height, masked.rect);
                    applyMask(mask, masked, false);
                } catch (e:ArgumentError) {
                }
            }
			var list:Array = [];
			for each (m in _tagMasks) {
				if (list.indexOf(m) == -1) {
					list.push(m);
				}
			}
			for each (m in list) {
				//trace('gonna remove index', _childs.indexOf(m));
				_childs.splice(_childs.indexOf(m), 1);
				m.dispose();
			}
		}

        public function fromDisplayObject(obj:DisplayObject, scale:Number = 1, tag:IDefinitionTag = null):IFlatten {
			//Utils.traceObj(obj as DisplayObjectContainer);
			_scale = scale;

            cleanMasks();
            flatten(obj);
			
			prepareParseTags();
			//parseTags(tag, obj is MovieClip ? (obj as MovieClip).currentFrame : 1); //фреймы идут с 1
			//if ((obj as MovieClip).currentFrame == 8) {
				//trace(1123123123123123);
			//}
			
			var res:Array = parseTags2(tag, obj is MovieClip ? (obj as MovieClip).currentFrame : 1); //фреймы идут с 1
			
			var hasMask:Boolean = false;
			for (var o:Object in res[1]) {
				hasMask = true;
				break;
			}
			
			if (hasMask) {
				//не проверяем тэги у объектов которые заведомо не маскируются
				defineTagMasks(res[0], res[1]);
			}
			
            applyMasks();
            applyTagMasks();

            var i:uint = 0;

            while (i < _childs.length) {
                //trace("mda " + i + " " + _childs.length);

                var fimg:FlattenImage = _childs[i] as FlattenImage;

                if (fimg == null || fimg == maskForAll) {
                    i++;
                    continue;
                }

                //trace("1");

                if (_namedMasks.hasOwnProperty(fimg.name)) {
                    i = applyMask(_namedMasks[fimg.name], fimg);
                    continue;
                }

                //trace("2");

                if (maskForAll != null) {
                    i = applyMask(maskForAll, fimg, false);
                    continue;
                }

                //trace("3");

                i++;
            }

            //trace("4");

            if (maskForAll != null) {
                _childs.splice(_childs.indexOf(maskForAll), 1);
                maskForAll.dispose();
            }
			//clipTransparency();

            //trace("5");

            return this;
        }

		public function get childs():Vector.<IFlatten> {
			return _childs;
		}

		public function dispose():void {
			for each (var child:IFlatten in _childs) {
				if (child is FlattenImage) {
					(child as FlattenImage).dispose();
				}
			}
		}

		public function render():void {
			while (numChildren) {
				removeChildAt(0);
			}

			for each (var child:IFlatten in childs) {
				var img:FlattenImage = child as FlattenImage;

				if (!img) {
					continue;
				}

				var bmp:Bitmap = new Bitmap(img.clone());
				bmp.transform.matrix = img.matrix;

				addChild(bmp);
			}
		}
	}
}