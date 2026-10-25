package backend.vslice;

import haxe.Json;
import backend.StageData;
import backend.StageData.StageFile;
import backend.vslice.VSliceMods.g;
#if MODS_ALLOWED
import sys.io.File;
#end

/**
 * Convierte `data/stages/<id>.json` (V-Slice) a StageFile de Psych.
 *
 * - Props -> objetos `sprite` / `animatedSprite` / `square` (assetPath "#RRGGBB" = rectángulo sólido).
 * - Orden de capas por `zIndex`; los personajes entran como objetos `dad`/`gf`/`boyfriend`.
 * - Las posiciones de personajes de V-Slice son los PIES (centro-abajo). El StageFile se marca con
 *   `_editorMeta.vsliceAnchor = true` y PlayState.startCharacterPos resta (ancho/2, alto).
 * - `cameraOffsets` de V-Slice reemplazan los valores fijos de Psych (bf -100,-100 / dad +150,-100),
 *   por eso se descuentan aquí para que la cámara quede igual que en V-Slice.
 */
class StageConverter
{
	public static function load(stageId:String):Null<StageFile>
	{
		var path = VSliceMods.findFile('data/stages/$stageId.json');
		if (path == null) return null;
		#if MODS_ALLOWED
		try
		{
			return convert(File.getContent(path), stageId);
		}
		catch (e:Dynamic)
		{
			trace('[VSlice] Error stage $stageId: $e');
		}
		#end
		return null;
	}

	/** Lee un array de números de un Dynamic (JSON) sin depender de casts de Array. */
	static function nums(a:Dynamic, def:Array<Float>):Array<Float>
	{
		if (a == null || !Std.isOfType(a, Array)) return def.copy();
		var src:Array<Dynamic> = a;
		var out:Array<Float> = [];
		for (x in src) out.push(x);
		while (out.length < def.length) out.push(def[out.length]);
		return out;
	}

	/** `scale` puede ser un número o [x, y]. */
	static function scale2(a:Dynamic):Array<Float>
	{
		if (a == null) return [1, 1];
		if (Std.isOfType(a, Array))
		{
			var n:Array<Float> = nums(a, [1, 1]);
			return (n.length == 1) ? [n[0], n[0]] : [n[0], n[1]];
		}
		var f:Float = a;
		return [f, f];
	}

	static function hexOf(c:Dynamic, def:String):String
	{
		if (c == null) return def;
		var s:String = Std.string(c);
		return s.startsWith('#') ? s.substr(1) : s;
	}

	public static function convert(raw:String, stageId:String):StageFile
	{
		var data:Dynamic = Json.parse(raw);
		var props:Array<Dynamic> = g(data, 'props', []);
		var chars:Dynamic = g(data, 'characters', {});
		var bf:Dynamic = g(chars, 'bf', {});
		var dad:Dynamic = g(chars, 'dad', {});
		var gf:Dynamic = g(chars, 'gf', {});

		var ordered:Array<Dynamic> = [];
		for (i in 0...props.length)
		{
			var p:Dynamic = props[i];
			ordered.push({z: g(p, 'zIndex', i), order: i, kind: 'prop', value: p});
		}
		ordered.push({z: g(gf, 'zIndex', 100), order: 10000, kind: 'gf', value: gf});
		ordered.push({z: g(dad, 'zIndex', 200), order: 10001, kind: 'dad', value: dad});
		ordered.push({z: g(bf, 'zIndex', 300), order: 10002, kind: 'boyfriend', value: bf});
		ordered.sort(function(a:Dynamic, b:Dynamic):Int
		{
			if (a.z < b.z) return -1;
			if (a.z > b.z) return 1;
			return Std.int(a.order) - Std.int(b.order);
		});

		var objects:Array<Dynamic> = [];
		for (item in ordered)
		{
			if (item.kind != 'prop')
			{
				objects.push({type: item.kind, name: item.kind});
				continue;
			}

			var p:Dynamic = item.value;
			var asset:String = g(p, 'assetPath', '');
			if (asset == null || asset.length == 0) continue;

			var pos:Array<Float> = nums(g(p, 'position', null), [0, 0]);
			var scroll:Array<Float> = nums(g(p, 'scroll', null), [1, 1]);
			var sc:Array<Float> = scale2(g(p, 'scale', null));
			var isPixel:Bool = g(p, 'isPixel', false);
			var name:String = g(p, 'name', 'vsliceProp' + objects.length);

			// assetPath "#RRGGBB": rectángulo sólido; `scale` es su tamaño en píxeles
			if (asset.startsWith('#'))
			{
				objects.push({
					type: 'square', name: name,
					x: pos[0], y: pos[1], scale: sc, scroll: scroll,
					color: hexOf(asset, 'FFFFFF'), alpha: g(p, 'alpha', 1), angle: g(p, 'angle', 0),
					filters: 3
				});
				continue;
			}

			var rawAnims:Array<Dynamic> = g(p, 'animations', []);
			var anims:Array<Dynamic> = [];
			for (a in rawAnims)
			{
				var prefix:String = g(a, 'prefix', '');
				if (prefix.length == 0) continue;
				anims.push({
					anim: g(a, 'name', prefix),
					name: prefix,
					fps: Std.int(g(a, 'frameRate', 24)),
					loop: g(a, 'looped', false),
					indices: g(a, 'frameIndices', []),
					offsets: nums(g(a, 'offsets', null), [0, 0])
				});
			}

			var first:String = g(p, 'startingAnimation', '');
			if (first == null) first = '';

			objects.push({
				type: anims.length > 0 ? 'animatedSprite' : 'sprite',
				name: name,
				image: asset,
				x: pos[0],
				y: pos[1],
				scale: sc,
				scroll: scroll,
				color: hexOf(g(p, 'color', null), 'FFFFFF'),
				alpha: g(p, 'alpha', 1),
				angle: g(p, 'angle', 0),
				flipX: g(p, 'flipX', false),
				flipY: g(p, 'flipY', false),
				antialiasing: !isPixel,
				filters: 3,
				animations: anims,
				firstAnimation: first
			});
		}

		var bfPos:Array<Float> = nums(g(bf, 'position', null), [989.5, 885]);
		var dadPos:Array<Float> = nums(g(dad, 'position', null), [335.5, 885]);
		var gfPos:Array<Float> = nums(g(gf, 'position', null), [751.5, 787]);
		var bfCam:Array<Float> = nums(g(bf, 'cameraOffsets', null), [0, 0]);
		var dadCam:Array<Float> = nums(g(dad, 'cameraOffsets', null), [0, 0]);
		var gfCam:Array<Float> = nums(g(gf, 'cameraOffsets', null), [0, 0]);

		return {
			directory: g(data, 'directory', ''),
			defaultZoom: g(data, 'cameraZoom', 0.9),
			stageUI: 'normal',
			boyfriend: bfPos,
			girlfriend: gfPos,
			opponent: dadPos,
			hide_girlfriend: false,
			// Psych ya suma bf (-100,-100) y dad (+150,-100) en moveCamera; V-Slice no, así que se compensa.
			camera_boyfriend: [bfCam[0] + 100, bfCam[1] + 100],
			camera_opponent: [dadCam[0] - 150, dadCam[1] + 100],
			camera_girlfriend: gfCam,
			camera_speed: 1,
			objects: objects,
			_editorMeta: {vsliceAnchor: true}
		};
	}
}
