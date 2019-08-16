package rasterizer.flatten;
	

import openfl.filters.ColorMatrixFilter;
import lime.math.ColorMatrix;
import sys.io.File;
import openfl.display.PNGEncoderOptions;
import format.swf.tags.ITag;
import format.swf.SWFTimelineContainer;
import format.swf.tags.TagDefineSprite;
import format.swf.tags.IDefinitionTag;
import format.swf.SWFRoot;
import openfl.errors.Error;

import format.swf.tags.TagRemoveObject;
import format.swf.tags.TagRemoveObject2;
import format.swf.tags.TagEnd;
import format.swf.tags.TagShowFrame;
import format.swf.tags.TagFrameLabel;
import format.swf.tags.TagSoundStreamHead;

import format.swf.tags.TagPlaceObject;
import format.swf.tags.TagPlaceObject2;
import format.swf.tags.TagPlaceObject3;
import format.swf.tags.TagPlaceObject4;

import openfl.errors.ArgumentError;
import format.swf.tags.IDisplayListTag;
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

import rasterizer.flatten.FlattenImage;
import rasterizer.flatten.IFlatten;
import rasterizer.model.SWFClass;
import rasterizer.InnerGlowFilter;



using StringTools;


@:access(flash.display.DisplayObject)
class FlattenSprite extends Sprite implements IFlatten {

    public static inline var BMP_SMOOTHING_MISTAKE : Float = 0;

	private var __scale : Float;

	private var __flattenChildren : Array<IFlatten>;

	// ключ - имя маски, значение - изображение, которое будет выступать в роли маски
    private var __masks : Map<String, FlattenImage>;

	// Ключ - маскируемый объект, String - имя маски. Сама маска по этому ключу находится в __masks
    private var __masked : Map<FlattenImage, String>; 

	
	//
    private var __namedMasks : Map<String, FlattenImage>;

	//
    private var maskForAll:FlattenImage;

	//
    public var label : String = '';

	
	public var swf : SWFRoot;


	//	
	private var __tagMasked : Map<IFlatten, Int>;
    
	// 
	private var __tagMasks : Map<Int, IFlatten>;


	public var children(get, null) : Array<IFlatten>;

	// если этот флаг выставлен, то мы не применяем маски, а записываем их в мету
	public var preserveTagMasks : Bool;


	/*
	 *
	 */
	public function new() {
		super();
		__flattenChildren = [];
		__scale = 1.0;
		__masks = new Map();
		__masked = new Map();
		__namedMasks = new Map();
	}

	private static var  dbgcounter = 1;

	private static function writeFlattenImage(img : FlattenImage, file : String) : Void {
		var binary = img.encode(img.rect, new PNGEncoderOptions(false));
		File.saveBytes(file, binary);
	}
	
	
	/*
	 *
	 */
	private function applyFilters(obj : FlattenImage, filters : Array<BitmapFilter>) : FlattenImage {		

		var saved = lime.system.CFFI.enabled;
		lime.system.CFFI.enabled = false;

        var finalRect = new Rectangle(0, 0, obj.width, obj.height);
        var m = obj.matrix;
		var name = obj.name;

		var i = 1;

		for (filter in filters) {
		
			// trace('Applying filter $filter $i / ${filters.length} [$dbgcounter]');
			// i++;
			// не применяем inner glow
			if (Std.is(filter, openfl.filters.GlowFilter)) {
				var filter2 : openfl.filters.GlowFilter = cast filter;
				if (filter2.knockout) {
					trace('Skipped inner knockout glow filter');
					continue;
				} 

				if (filter2.inner) {
					filter = new InnerGlowFilter(filter2.color, filter2.alpha, filter2.blurX, filter2.blurY, filter2.strength, filter2.quality);
				}
			}

            var srcRect = new Rectangle(0, 0, obj.width, obj.height);            			
			var filterRect  = obj.generateFilterRect(srcRect, filter);			
			var objLayer    = new FlattenImage(Std.int(filterRect.width), Std.int(filterRect.height), true, 0x00000000); 
			var filterLayer = new FlattenImage(Std.int(filterRect.width), Std.int(filterRect.height), true, 0x00000000);

			objLayer.copyPixels(obj, srcRect, new Point( Std.int((filterRect.width - srcRect.width) / 2), Std.int((filterRect.height - srcRect.height) / 2)));		
			finalRect = finalRect.union(filterRect);
			
            // filterLayer.applyFilter(obj, srcRect, new Point(-filterRect.x, -filterRect.y), filter);			
			// writeFlattenImage(obj, 'debug/OBJ_${dbgcounter}.png');
			// writeFlattenImage(objLayer, 'debug/OBJ_COPY_${dbgcounter}.png');

			filterLayer.applyFilter(objLayer, filterRect, new Point(0, 0), filter);			

			// writeFlattenImage(filterLayer, 'debug/FILTERED_${dbgcounter}.png');
			// dbgcounter++;

			objLayer.dispose();
            obj.dispose();
            obj = filterLayer;
        }

        m.translate(finalRect.x, finalRect.y);
        obj.matrix = m;
		obj.name = name;
		lime.system.CFFI.enabled = saved;
        return obj;
    }

    
	/*
	 *
	 */
	private function getTransformedBounds(rect : Rectangle, m : Matrix) : Rectangle {
        var points : Array<Point> = [];
        
		points.push(m.transformPoint(new Point(rect.x, rect.y)));
        points.push(m.transformPoint(new Point(rect.x + rect.width, rect.y)));
        points.push(m.transformPoint(new Point(rect.x + rect.width, rect.y + rect.height)));
        points.push(m.transformPoint(new Point(rect.x, rect.y + rect.height)));

        var lt = new Point(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
        var rb = new Point(Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY);
        
		for (p in points) {
            lt.x = Math.min(lt.x, p.x);
            lt.y = Math.min(lt.y, p.y);
            rb.x = Math.max(rb.x, p.x);
            rb.y = Math.max(rb.y, p.y);
        }

        var retval = new Rectangle(lt.x, lt.y, rb.x - lt.x, rb.y - lt.y);
        
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


	/*
	 *
	 */
    private function applyMatrix(obj : DisplayObject, mtx : Matrix, scale : Float, color : ColorTransform) : FlattenImage {
		mtx.scale(scale, scale);
		var rect = getTransformedBounds(obj.getRect(obj), mtx);
	
		// trace('GOT BOUNDS $rect SCALE = $scale OBJECT SCALE = ${obj.scaleX}');

		rect.width = rect.width < 1 ? 1 : rect.width;
        rect.height = rect.height < 1 ? 1 : rect.height;

        var objBmpData:FlattenImage = new FlattenImage(Math.ceil(rect.width), Math.ceil(rect.height), true, 0x00000000);

        var m:Matrix = mtx.clone();		
        m.translate(-rect.x, -rect.y);

		// trace('Drawing with matrix $m');

		var oldsx = obj.scaleX;
		var oldsy = obj.scaleY;

		obj.scaleX *= scale;		
		obj.scaleY *= scale;
	
        objBmpData.drawWithQuality(obj, m, color, null, null, true, flash.display.StageQuality.BEST);		

		// writeFlattenImage(objBmpData, 'DEBUG_${dbgcounter}.png');
		// dbgcounter++;

        objBmpData.matrix = new Matrix(1, 0, 0, 1, Math.round(rect.x), Math.round(rect.y));
        objBmpData.name = obj.name;

	
		obj.scaleX = oldsx;		
		obj.scaleY = oldsy;

        return objBmpData;
    }



	/*
	 *
	 */
    private function applyMask(mask : FlattenImage, masked : FlattenImage, disposeMask : Bool = true) : Int {

        var maskedRect = new Rectangle(Math.floor(masked.matrix.tx), Math.floor(masked.matrix.ty), masked.width, masked.height);
        var maskRect  = new Rectangle(Math.floor(mask.matrix.tx), Math.floor(mask.matrix.ty), mask.width, mask.height);        
		var intersection = maskedRect.intersection(maskRect);
        var retval : Int = -1;
		
		if (intersection.isEmpty()) {
            
			if (disposeMask) {
                __flattenChildren.splice(__flattenChildren.indexOf(mask), 1);
                mask.dispose();
            }

            retval = __flattenChildren.indexOf(masked);
            __flattenChildren.splice(__flattenChildren.indexOf(masked), 1);
            return retval;
        }

        var srcRect = new Rectangle(intersection.x - maskRect.x, intersection.y - maskRect.y, intersection.width, intersection.height);
        var dstPnt  = new Point(intersection.x - maskedRect.x, intersection.y - maskedRect.y);

		masked.threshold(mask, srcRect, dstPnt, '==', 0x00000000, 0x00000000, 0xff000000);

		var maskedFinal = new FlattenImage(Std.int(intersection.width), Std.int(intersection.height), true, 0x00000000);        

		var saved = lime.system.CFFI.enabled;
		lime.system.CFFI.enabled = false;
		maskedFinal.copyPixels(masked, new Rectangle(dstPnt.x, dstPnt.y, intersection.width, intersection.height), new Point(0, 0));
		lime.system.CFFI.enabled = saved;

        if (disposeMask) {
            __flattenChildren.splice(__flattenChildren.indexOf(mask), 1);
            mask.dispose();
        }

        retval = __flattenChildren.indexOf(masked);
        __flattenChildren.splice(retval, 1);
		__flattenChildren.insert(retval, maskedFinal);        
        maskedFinal.name = masked.name;
        maskedFinal.matrix = new Matrix(1, 0, 0, 1, intersection.x, intersection.y);
		masked.dispose();
        return retval + 1;
    }
		


	/*
	 *
	 */
    private inline function cleanMasks() {
        __masks = new Map();
        __masked = new Map();
    }


        

	/*
	 * 
	 */	
	private function flatten(obj : DisplayObject, matrix : Matrix = null, color : ColorTransform = null, filters : Array<BitmapFilter> = null, name : String = null) {
		if (obj == null) {
			return;
		}

		
		//хак, таким образом убиваем маски таймлайна		
		if (obj.mask != null) {
			obj.mask = null; 
		}
		

		if (!obj.visible && obj.__isMask) {
			obj.visible = true;
			obj.__isMask = false;
		}

        if (matrix == null) {
            matrix = new Matrix();
        }

        if (color == null) {
            color = new ColorTransform();
        }

        if (filters == null) {
            filters = new Array();
        }

        
		var container : DisplayObjectContainer = null;
		if (Std.is(obj, DisplayObjectContainer)) {
			container = cast obj;
		}
        
		var clr = new ColorTransform(color.redMultiplier, color.greenMultiplier, color.blueMultiplier, color.alphaMultiplier, color.redOffset, color.greenOffset, color.blueOffset, color.alphaOffset);
        clr.concat(obj.transform.colorTransform);

		var mtx = obj.transform.matrix.clone();
		mtx.concat(matrix);

	    if (container != null) {

			// если так не сделать, то у MC не будет чайлдов.
			if (Std.is(container, format.swf.instance.MovieClip)) {
				var mc : format.swf.instance.MovieClip = cast container;
				if (mc.scale9BitmapGrid != null) {
					mc.scale9BitmapGrid = null;
				}
			}

					
			var customName = ! (obj.name.startsWith("instance") || obj.name.startsWith("masked") || obj.name.startsWith("mask"));

			if (obj.filters != null) {
				filters = obj.filters.concat(filters);
			}			
    
            if (container.numChildren == 0 && customName) {
                mtx.scale(__scale, __scale);
                var box = new FlattenSprite();
                box.name = obj.name;
                box.transform.matrix = mtx.clone();
                __flattenChildren.push(box);
				return;
            } 
			
			if (container.numChildren == 1 && customName) {
                flatten(container.getChildAt(0), mtx, clr, filters, container.name);
				return;
            } 
			
			
            for (i in 0...container.numChildren) {
                flatten(container.getChildAt(i), mtx, clr, filters);
            }
            
			return;
        } 
		// scale передаем в applyMatrix, такой хак для того, чтобы работало на cairo
		var layer = applyFilters(applyMatrix(obj, mtx, __scale, clr), filters);		
        __flattenChildren.push(layer);

	    if (name != null) {
            layer.name = name;
        }
		
        if (obj.parent.name == "maskfor_all") {
            maskForAll = layer;
			return;
        } 
        
		var re = ~/^(masked|mask)([\d]+)$/;		    
        if (!re.match(obj.parent.name)) {
			var re = ~/^maskfor_(.+)$/;
            if (!re.match(obj.parent.name)) {
                return;
            }
            __namedMasks[re.matched(1)] = layer;
        }
        if (re.matched(1) == 'masked') {
            __masked[layer] = re.matched(2);
        } else {
            __masks[re.matched(2)] = layer;
        }
	}

	

	/*
	 *
	 */
	public function fromSwfClass(cls : SWFClass, scale : Float) : IFlatten {
		swf = cls.root;
		return fromDisplayObject(cls.createInstance(), scale, cls.tag);
	}
		

		
	/*
	 * Создает связку какие объекты какими объектами маскируются.
	 * __tagMasked по объекту (IFlatten) получает некий ключ, по которому можно получить из __tagMask объект-маску
	 */
	private function defineTagMasks(flattenTags : Map<Int, IDisplayListTag>, flattenClips : Map<Int, Int>) {
		var indexes = new Array<Int>();

		for (depth in flattenTags.keys()) { // тут точно keys
			indexes.push(depth);
		}

		indexes.sort(function(a, b) return a - b);

		if (indexes.length != __flattenChildren.length) {
			throw new Error('wrong number of childs');
		}
		
		var incremental = 0;

		for (depth in flattenClips.keys()) {			
			var clip = flattenClips[depth];			
			for (depth2 in flattenTags.keys()) {

				if (depth2 > depth && depth2 <= clip) {
					__tagMasks[10000 + incremental] = __flattenChildren[indexes.indexOf(depth)];
					__tagMasked[__flattenChildren[indexes.indexOf(depth2)]] = 10000 + incremental;
					incremental++;
				}
			}
		}
	}

	
	/*
	 *
	 */
	private inline function prepareParseTags() {
		__tagMasked = new Map();
		__tagMasks = new Map();
	}


	/* 
	 * 
	 */
	public function concatTagLayers<T>(target : Map<Int,T>, source : Map<Int, T>, depth:Int) {
		for (index in source.keys()) {
			target[index + depth] = source[index];
		}
	}



	/*
	 *
	 */
	public function parseTags2(root : IDefinitionTag, targetFrameIndex : Int) : Array<Dynamic> {
		
		if (!Std.is(root, SWFTimelineContainer)) {
			throw new Error('definition tag ' + root.name + ' is not supported!');
		}
		

		// везде ключ - depth
		var result  = new Map<Int, IDisplayListTag>();
		var clip    = new Map<Int, Int>();
		var offsets = new Map<Int, Int>();
		
		var frameIndex = 0;
		var isEnd = false;
		
		var container : SWFTimelineContainer = cast root;
		
		for (i in 0...container.tags.length) {			
			
			if (targetFrameIndex == frameIndex) {
				break;
			}

			var tag:ITag = container.tags[i];
						
			if (isEnd) {
				throw new Error('swf ended too early!');
			}
			
			if (Std.is(tag, TagPlaceObject) || Std.is(tag, TagPlaceObject2) || Std.is(tag, TagPlaceObject3) || Std.is(tag, TagPlaceObject4) ) {
				placeObject(cast tag, frameIndex, result, clip, offsets);
				continue;
			} 
			
			if (Std.is(tag, TagRemoveObject) || Std.is(tag, TagRemoveObject2)) {
				removeObject(cast tag, result, clip, offsets);
				continue;
			} 
			
			if (Std.is(tag, TagShowFrame)) {
				frameIndex++;
				continue;
			} 
			
			if (Std.is(tag, TagEnd)) {
				isEnd = true;
				continue;
			} 
			
			if (!(Std.is(tag,TagFrameLabel) || Std.is(tag, TagSoundStreamHead))) {
				throw new Error('inner tag ' + tag.name + ' is not supported!');
			}			
		}
		
		var toAdd = new Map<Int, IDisplayListTag>();
		var toRemove = new Array<Int>();
		
		for (depth in result.keys()) {
			
			var tpo : TagPlaceObject = cast result[depth];
			if (!Std.is(tpo, TagPlaceObject) || !tpo.hasCharacter) {
				throw new Error('fffffffffffff'); //по идее невозможно, всегда будет hasCharacter
			}

			var def = swf.getCharacter(tpo.characterId);
			
			if (Std.is(def, SWFTimelineContainer)) {
				var res = parseTags2(def, targetFrameIndex - offsets[tpo.depth]);
				
				var _tags : Map<Int, IDisplayListTag> = cast res[0];
				var _clip : Map<Int, Int> = res[1];

				var cnt = 0;
				var ind = 0;
				
				// ПОЧЕМУ ТАК???? почему не characterId??????
				for (ind in _tags) {
					cnt++;
					if (cnt > 1) {
						break;
					}
				}
				
				if (cnt == 1) {
					var def = swf.getCharacter(ind); // почему блять depth???
					if (!Std.is(def, TagDefineSprite)) {
						continue; //основываясь на теории, что спрайт с одним шейпом занимает 1 глубину, а не 2
					}
				}
				
				toRemove.push(depth);
				
				concatTagLayers(toAdd, _tags, tpo.depth);				
				concatTagLayers(clip,  _clip, tpo.depth);
				
				for (dp in clip) {
					if (dp == depth) {
						var nv = 0;
						for (t in _tags.keys()) {
							nv = t + tpo.depth;
							break; //первый индекс берем
						}
						clip[nv] = clip[depth];
						clip.remove(depth);
					}
				}

			}
		}


		for (depth in toRemove) {
			result.remove(depth);
		}

		for (depth in toAdd.keys()) {
			if (result.exists(depth)) {
				throw new Error('aaaaaaaaaaaaaaa'); //это очень плохо
			} else {
				result[depth] = toAdd[depth];
			}
		}
		
		return [result, clip];
	}
		

	/* 
	 * 
	 */
	private function placeObject(tpo : TagPlaceObject, currentFrameIndex : Int, result : Map<Int, IDisplayListTag>, clip : Map<Int, Int>, offsets : Map<Int, Int>) {
		if (!tpo.hasMove && tpo.hasCharacter && !result.exists(tpo.depth)) {
			result[tpo.depth] = tpo;
			offsets[tpo.depth] = currentFrameIndex;
			if (tpo.hasClipDepth) {
				clip[tpo.depth] = tpo.clipDepth;
			}
		} else if (tpo.hasMove && !tpo.hasCharacter && result.exists(tpo.depth)) {
			if (tpo.hasClipDepth) {
				throw new Error('TagPlaceObject2 hasMove and hasClipDepth');
			}
		} else if (tpo.hasMove && tpo.hasCharacter && result.exists(tpo.depth)) {
			
			if (offsets.exists(tpo.depth)) {
				offsets.remove(tpo.depth);
			}

			if (clip.exists(tpo.depth)) {
				clip.remove(tpo.depth);
			}
			
			result.remove(tpo.depth);			
			result[tpo.depth] = tpo;
			offsets[tpo.depth] = currentFrameIndex;
			if (tpo.hasClipDepth) {
				clip[tpo.depth] = tpo.clipDepth;
			}
		} else {
			throw new Error(tpo.name + ' has wrong attributes');
		}
	}


	/*
	 * 
	 */	
	private function removeObject(tro : TagRemoveObject, result : Map<Int, IDisplayListTag>, clip : Map<Int, Int>, offsets : Map<Int, Int>) {
		if (result.exists(tro.depth)) {
			if (offsets.exists(tro.depth)) {
				offsets.remove(tro.depth);
			}

			if (clip.exists(tro.depth)) {
				clip.remove(tro.depth);
			}
			
			result.remove(tro.depth);
		} else {
			throw new Error(tro.name + ' has wrong attributes');
		}
	}


		
		
		
	/*
	 *
	 */
	public function applyTagMasks() {
		for (obj in __tagMasked.keys()) {
			var obj : FlattenImage = cast obj;
            try {
                var objmask : FlattenImage = cast __tagMasks[__tagMasked[obj]];
                if (objmask == null) {
                    continue;
                }
				
				if (preserveTagMasks) {
					obj.mask = objmask.name;
				} else {
                	applyMask(objmask, obj, false);
				}
            } catch (e:ArgumentError) {
            }			
        }

		if (preserveTagMasks) {
			return;
		}

		var list:Array<IFlatten> = [];
		for (m in __tagMasks) {
			if (list.indexOf(m) == -1) {
				list.push(m);
			}
		}


		for (m in list) {		
			var idx = __flattenChildren.indexOf(m);
			__flattenChildren.splice(idx, 1);
			m.dispose();
		}
	}



	/*
	 *
	 */
    private function applyMasks() {
        for (obj in __masked.keys()) {
            try {
                var objmask : FlattenImage = __masks[__masked[obj]];
                if (objmask == null) {
                    continue;
                }

				if (preserveTagMasks) {
					obj.mask = objmask.name;
				} else {
                	applyMask(objmask, obj);
				}

                // applyMask(objmask, obj);
            } catch (e:ArgumentError) {
            }
        }
    }


	/*
	 * 
	 */
    public function fromDisplayObject(obj : DisplayObject, scale : Float = 1.0, tag : IDefinitionTag = null) : IFlatten {
		__scale = scale;

		cleanMasks();
        flatten(obj);		
		prepareParseTags();
		
		var res : Array<Dynamic> = parseTags2(tag, Std.is(obj, MovieClip) ? cast(obj, MovieClip).currentFrame : 1); //фреймы идут с 1		
		var tags : Map<Int, IDisplayListTag> = cast res[0];
		var clip : Map<Int, Int> = cast res[1];
		var hasMask = clip.keys().hasNext();

		//не проверяем тэги у объектов которые заведомо не маскируются
		if (hasMask) {		
			defineTagMasks(tags, clip);
		}
		
		// никаких named masks
        // applyMasks();
        applyTagMasks();
        
		/*
		var i = 0;
        while (i < __flattenChildren.length) {
            
			var fimg : FlattenImage = null;
			if (Std.is(__flattenChildren[i], FlattenImage)) {
				fimg = cast __flattenChildren[i];
			}

            if (fimg == null || fimg == maskForAll) {
                i++;
                continue;
            }

            if (__namedMasks.exists(fimg.name)) {
                i = applyMask(__namedMasks[fimg.name], fimg);
                continue;
            }

            if (maskForAll != null) {
                i = applyMask(maskForAll, fimg, false);
                continue;
            }

            i++;
        }

        if (maskForAll != null) {
            __flattenChildren.splice(__flattenChildren.indexOf(maskForAll), 1);
            maskForAll.dispose();
        }
		*/

        return this;
    }

		
	/*
	 *
	 */
	private function get_children() : Array<IFlatten> {
		return __flattenChildren;
	}



	/*
	 *
	 */	
	public function dispose() {

		for (child in __flattenChildren) {
			if (!Std.is(child, FlattenImage)) {
				continue;
			}
			var img : FlattenImage = cast child;
			img.disposeImage();
			img.dispose();
		}
		
		__flattenChildren = null;		
		__masks = null;
		__masked = null;
		__namedMasks = null;
		while (numChildren > 0) {
			removeChildAt(0);
		}
	
	}


	/*
	 *
	 */
	public function render() {
		while (numChildren > 0) {
			removeChildAt(0);
		}
		
		
		for (child in __flattenChildren) {						
			
			if (!Std.is(child, FlattenImage)) {
				continue;
			}
			
			var img : FlattenImage = cast child;
			var bmp = new Bitmap(img.clone());
			bmp.transform.matrix = img.matrix;
			addChild(bmp);
		}
		

	}


}
