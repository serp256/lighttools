(*
 *	alpha threshold -- alpha value which treated as transparent
 *	line threshold -- value determining approximation quality: 0 means best contour quality and with increasing of this value contour becomes more rough
 *)

value gen: ?alphaThreshold:int -> ?lineTreshold:float -> Rgba32.t -> (int * int) list;