package backend.vslice;

import haxe.Json;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

typedef VSliceSongEntry =
{
	var id:String;
	var name:String;
	var artist:String;
	var mod:String;
	var opponent:String;
	var difficulties:Array<String>;
	var variations:Array<String>;
}

/**
 * Punto de entrada del soporte de mods V-Slice (Funkin' 0.5+) para Psych.
 *
 * Los mods V-Slice se tratan como mods normales de Psych (misma carpeta `mods/`,
 * mismos assets via Paths.modFolders). Esta clase solo localiza sus archivos de
 * datos (`data/songs`, `data/characters`, ...) y los convierte al formato de Psych.
 */
class VSliceMods
{
	public static inline var META_FILE:String = '_polymod_meta.json';

	/** Lectura segura de campos de un Dynamic (null-safe, con valor por defecto). */
	public static function g(o:Dynamic, key:String, ?def:Dynamic):Dynamic
	{
		if (o == null) return def;
		var v:Dynamic = Reflect.field(o, key);
		return v == null ? def : v;
	}

	/** ¿Esta carpeta de `mods/` es un mod estilo V-Slice/Polymod? */
	public static function isVSliceMod(dir:String):Bool
	{
		#if MODS_ALLOWED
		return Paths.resolveModPath(Paths.mods('$dir/$META_FILE')) != null;
		#else
		return false;
		#end
	}

	/** Busca un archivo relativo (ej. `data/songs/bopeebo/bopeebo-chart.json`) en los mods activos. */
	public static function findFile(rel:String):Null<String>
	{
		#if MODS_ALLOWED
		var p:String = Paths.modFolders(rel);
		if (FileSystem.exists(p)) return p;

		for (mod in Mods.parseList().enabled)
		{
			var q:String = Paths.resolveModPath(Paths.mods('$mod/$rel'));
			if (q != null) return q;
		}
		#end
		return null;
	}

	static function readJson(path:String):Dynamic
	{
		#if MODS_ALLOWED
		try
		{
			return Json.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			trace('[VSlice] No se pudo leer $path: $e');
		}
		#end
		return null;
	}

	/**
	 * Convierte `inputJson` de Psych (ej. `bopeebo-hard`) + carpeta (`bopeebo`) en una dificultad.
	 * Sin sufijo = `normal`, igual que hace Psych.
	 */
	public static function difficultyFromInput(jsonInput:String, folder:String):String
	{
		var d:String = jsonInput.toLowerCase();
		var f:String = folder.toLowerCase();
		if (d.startsWith(f)) d = d.substr(f.length);
		if (d.startsWith('-')) d = d.substr(1);
		return d.length == 0 ? 'normal' : d;
	}

	/**
	 * Carga una canción V-Slice ya convertida a formato Psych (o null si no existe).
	 * Prueba la variación `default` y luego las listadas en `playData.songVariations`.
	 */
	public static function loadSong(songId:String, difficulty:String):Dynamic
	{
		#if MODS_ALLOWED
		songId = songId.toLowerCase();
		var variations:Array<String> = ['default'];

		var defMeta:Null<String> = findFile('data/songs/$songId/$songId-metadata.json');
		if (defMeta != null)
		{
			var vars:Array<String> = g(g(readJson(defMeta), 'playData', {}), 'songVariations', []);
			variations = variations.concat(vars);
		}

		for (v in variations)
		{
			var suffix:String = (v == 'default') ? '' : '-$v';
			var metaPath:Null<String> = findFile('data/songs/$songId/$songId-metadata$suffix.json');
			var chartPath:Null<String> = findFile('data/songs/$songId/$songId-chart$suffix.json');
			if (metaPath == null || chartPath == null) continue;

			var out:Dynamic = ChartConverter.convert(songId, File.getContent(metaPath), File.getContent(chartPath), difficulty);
			if (out != null)
			{
				out.vsliceVariation = v;
				return out;
			}
		}
		#end
		return null;
	}

	/** Personaje V-Slice (`data/characters/<id>.json`) convertido a CharacterFile de Psych, o null. */
	public static function loadCharacter(id:String):Dynamic
	{
		#if MODS_ALLOWED
		var path:Null<String> = findFile('data/characters/$id.json');
		if (path == null) return null;
		return CharacterConverter.convert(File.getContent(path), id);
		#else
		return null;
		#end
	}

	/** Lista las canciones V-Slice de los mods activos (para armar Freeplay en la siguiente fase). */
	public static function listSongs():Array<VSliceSongEntry>
	{
		var result:Array<VSliceSongEntry> = [];
		#if MODS_ALLOWED
		for (mod in Mods.parseList().enabled)
		{
			var root:String = Paths.mods('$mod/data/songs');
			if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) continue;

			for (song in FileSystem.readDirectory(root))
			{
				var metaPath:String = '$root/$song/$song-metadata.json';
				if (!FileSystem.exists(metaPath)) continue;

				var meta:Dynamic = readJson(metaPath);
				if (meta == null) continue;

				var play:Dynamic = g(meta, 'playData', {});
				var diffs:Array<String> = [for (d in (g(play, 'difficulties', []) : Array<String>)) d];
				var vars:Array<String> = g(play, 'songVariations', []);

				for (v in vars)
				{
					var vMeta:Dynamic = readJson('$root/$song/$song-metadata-$v.json');
					if (vMeta == null) continue;
					for (d in (g(g(vMeta, 'playData', {}), 'difficulties', []) : Array<String>))
						if (!diffs.contains(d)) diffs.push(d);
				}

				result.push({
					id: song,
					name: g(meta, 'songName', song),
					artist: g(meta, 'artist', ''),
					mod: mod,
					opponent: g(g(play, 'characters', {}), 'opponent', 'dad'),
					difficulties: diffs,
					variations: vars
				});
			}
		}
		#end
		return result;
	}
}
