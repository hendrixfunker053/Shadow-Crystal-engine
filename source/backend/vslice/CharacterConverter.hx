package backend.vslice;

import haxe.Json;
import backend.vslice.VSliceMods.g;

/**
 * Convierte `data/characters/<id>.json` (V-Slice) al CharacterFile de Psych.
 *
 * Notas:
 *  - `singTime` (V-Slice) se divide entre 1.1 porque Psych usa `stepCrochet * 0.0011`.
 *  - V-Slice no define color de barra de vida; se usa gris. Se puede sobrescribir luego.
 *  - Los offsets de animación se copian tal cual (misma convención en ambos motores).
 */
class CharacterConverter
{
	static final RENDER_TYPES:Array<String> = ['sparrow', 'multisparrow', 'packer', 'animateatlas'];

	/** Quita un prefijo de librería V-Slice ("shared:characters/x" -> "characters/x"). */
	static function stripLib(p:String):String
	{
		if (p == null) return '';
		var i:Int = p.indexOf(':');
		return i >= 0 ? p.substr(i + 1) : p;
	}

	public static function convert(jsonStr:String, ?id:String):Dynamic
	{
		var c:Dynamic = Json.parse(jsonStr);

		var renderType:String = g(c, 'renderType', 'sparrow');
		if (!RENDER_TYPES.contains(renderType))
			trace('[VSlice] renderType "$renderType" no soportado, se intentará como sparrow.');

		var images:Array<String> = [];
		var mainAsset:String = stripLib(g(c, 'assetPath', ''));
		if (mainAsset != '') images.push(mainAsset);

		var anims:Array<Dynamic> = [];
		var rawAnims:Array<Dynamic> = g(c, 'animations', []);
		for (a in rawAnims)
		{
			var ap:String = stripLib(g(a, 'assetPath', ''));
			if (ap != '' && !images.contains(ap)) images.push(ap);

			anims.push({
				anim: g(a, 'name', 'idle'),
				name: g(a, 'prefix', ''),
				fps: Std.int(g(a, 'frameRate', 24)),
				loop: g(a, 'looped', false),
				indices: g(a, 'frameIndices', []),
				offsets: g(a, 'offsets', [0, 0])
			});
		}

		var hi:Dynamic = g(c, 'healthIcon', null);
		var icon:String = (hi != null) ? g(hi, 'id', 'face') : 'face';

		var singTime:Float = g(c, 'singTime', 8);

		return {
			animations: anims,
			image: images.join(','),
			scale: g(c, 'scale', 1),
			sing_duration: Math.round(singTime / 1.1 * 10) / 10,
			healthicon: icon,
			position: g(c, 'offsets', [0, 0]),
			camera_position: g(c, 'cameraOffsets', [0, 0]),
			flip_x: g(c, 'flipX', false),
			no_antialiasing: g(c, 'isPixel', false),
			healthbar_colors: [161, 161, 161],
			// V-Slice nombra las voces `Voices-<idPersonaje>.ogg`; Psych las busca con este nombre.
			// Si no existe el archivo, PlayState cae a `Voices.ogg`.
			vocals_file: (id != null) ? id : ''
		};
	}
}
