package backend.vslice;

import haxe.Json;
#if MODS_ALLOWED
import sys.io.File;
#end
import backend.StageData;
import backend.StageData.StageFile;
import backend.vslice.VSliceMods.g;

/**
 * Convierte stages V-Slice sencillos a StageFile de Psych.
 * Soporta props estáticos, props Sparrow animados y posiciones/zIndex de personajes.
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
		// Psych's object list controls actual draw order, so insert character groups
		// into that same list using V-Slice zIndex.
		ordered.push({z: g(dad, 'zIndex', 8), order: 10000, kind: 'dad', value: dad});
		ordered.push({z: g(gf, 'zIndex', 7), order: 10001, kind: 'gf', value: gf});
		ordered.push({z: g(bf, 'zIndex', 8), order: 10002, kind: 'boyfriend', value: bf});
		ordered.sort(function(a:Dynamic, b:Dynamic):Int
		{
			if (a.z < b.z) return -1;
			if (a.z > b.z) return 1;
			return a.order - b.order;
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
			var pos:Array<Float> = cast g(p, 'position', [0, 0]);
			var scroll:Array<Float> = cast g(p, 'scroll', [1, 1]);
			var scale:Float = g(p, 'scale', 1.0);
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
					offsets: g(a, 'offsets', [0, 0])
				});
			}

			var obj:Dynamic = {
				type: anims.length > 0 ? 'animatedSprite' : 'sprite',
				name: g(p, 'name', 'vsliceProp' + objects.length),
				image: asset,
				x: pos.length > 0 ? pos[0] : 0,
				y: pos.length > 1 ? pos[1] : 0,
				scale: [scale, scale],
				scroll: scroll,
				color: 'FFFFFF',
				alpha: 1,
				angle: 0,
				flipX: false,
				flipY: false,
				antialiasing: true,
				filters: 3,
				animations: anims,
				firstAnimation: g(p, 'startingAnimation', '')
			};
			objects.push(obj);
		}

		var bfPos:Array<Float> = cast g(bf, 'position', [770, 100]);
		var dadPos:Array<Float> = cast g(dad, 'position', [100, 100]);
		var gfPos:Array<Float> = cast g(gf, 'position', [400, 130]);
		var bfCam:Array<Float> = cast g(bf, 'cameraOffsets', [0, 0]);
		var dadCam:Array<Float> = cast g(dad, 'cameraOffsets', [0, 0]);
		var gfCam:Array<Float> = cast g(gf, 'cameraOffsets', [0, 0]);

		return {
			directory: '',
			defaultZoom: g(data, 'cameraZoom', 0.9),
			stageUI: 'normal',
			boyfriend: bfPos,
			girlfriend: gfPos,
			opponent: dadPos,
			hide_girlfriend: false,
			camera_boyfriend: bfCam,
			camera_opponent: dadCam,
			camera_girlfriend: gfCam,
			camera_speed: 1,
			objects: objects
		};
	}
}
