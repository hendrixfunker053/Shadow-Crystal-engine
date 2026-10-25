package backend.vslice;

import haxe.Json;
import backend.WeekData;
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
		var requestedVariation:String = 'default';
		var baseId:String = songId;
		var defMeta:Null<String> = findFile('data/songs/$baseId/$baseId-metadata.json');
		if (defMeta == null)
		{
			var cut:Int = songId.lastIndexOf('-');
			if (cut > 0)
			{
				var candidateBase:String = songId.substr(0, cut);
				var candidateVar:String = songId.substr(cut + 1);
				var candidateMeta:Null<String> = findFile('data/songs/$candidateBase/$candidateBase-metadata.json');
				if (candidateMeta != null)
				{
					var declared:Array<String> = g(g(readJson(candidateMeta), 'playData', {}), 'songVariations', []);
					if (declared.contains(candidateVar) && findFile('data/songs/$candidateBase/$candidateBase-metadata-$candidateVar.json') != null)
					{ baseId = candidateBase; requestedVariation = candidateVar; defMeta = candidateMeta; }
				}
			}
		}
		if (defMeta == null) return null;
		var variations:Array<String> = requestedVariation == 'default' ? ['default'] : [requestedVariation];
		if (requestedVariation == 'default')
		{
			var vars:Array<String> = g(g(readJson(defMeta), 'playData', {}), 'songVariations', []);
			variations = variations.concat(vars);
		}

		for (v in variations)
		{
			var suffix:String = (v == 'default') ? '' : '-$v';
			var metaPath:Null<String> = findFile('data/songs/$baseId/$baseId-metadata$suffix.json');
			var chartPath:Null<String> = findFile('data/songs/$baseId/$baseId-chart$suffix.json');
			if (metaPath == null || chartPath == null) continue;

			var out:Dynamic = ChartConverter.convert(baseId, File.getContent(metaPath), File.getContent(chartPath), difficulty);
			if (out != null)
			{
				out.vsliceVariation = v;
				out.vsliceId = baseId;
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
		var out:Dynamic = CharacterConverter.convert(File.getContent(path), id);

		// Aviso útil en el log si la imagen del personaje no se encuentra (si no, solo se ve el logo de HaxeFlixel).
		for (part in (Std.string(out.image).split(',')))
		{
			var img:String = part.trim();
			if (img.length == 0) continue;
			if (!FileSystem.exists(Paths.modFolders('images/$img.png')) && !FileSystem.exists(Paths.modFolders('images/$img/Animation.json')))
				trace('[VSlice] Personaje "$id": no se encontró images/$img.png (se busca en <mod>/images y <mod>/shared/images)');
		}
		return out;
		#else
		return null;
		#end
	}

	/** Icono de salud del oponente según su JSON V-Slice (`healthIcon.id`), o `face`. */
	static function iconFor(characterId:String):String
	{
		var path:Null<String> = findFile('data/characters/$characterId.json');
		if (path != null)
		{
			var id:Dynamic = g(g(readJson(path), 'healthIcon', null), 'id', null);
			if (id != null) return id;
		}
		return 'face';
	}

	static function displayNameOf(e:VSliceSongEntry):String
		// FreeplayState usa formatToSongPath(nombre) como id de la canción.
		return (Paths.formatToSongPath(e.name) == e.id) ? e.name : e.id;

	static function diffsOf(e:VSliceSongEntry):Array<String>
	{
		var diffs:Array<String> = [for (d in e.difficulties) d.charAt(0).toUpperCase() + d.substr(1)];
		return diffs.length == 0 ? ['Normal'] : diffs;
	}

	static function makeWeek(key:String, mod:String, title:String, songs:Array<Dynamic>, diffs:Array<String>, story:Bool):Void
	{
		var wf:WeekFile = {
			songs: songs,
			weekCharacters: ['', 'bf', 'gf'],
			weekBackground: 'stage',
			weekBefore: '',
			storyName: title,
			weekName: title,
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: !story,
			hideFreeplay: story,
			difficulties: diffs.join(', ')
		};

		var week:WeekData = new WeekData(wf, key);
		week.folder = mod;
		WeekData.weeksLoaded.set(key, week);
		WeekData.weeksList.push(key);
	}

	/**
	 * Registra las canciones V-Slice como semanas de Psych para que FreeplayState, StoryMenuState,
	 * Difficulty y Highscore funcionen sin cambios:
	 *  - Freeplay: una semana por canción (`vslice-<mod>-<id>`), solo Freeplay.
	 *  - Story:    una semana por nivel (`data/levels/<nivel>.json`), solo Story Mode.
	 * Se llama al final de WeekData.reloadWeekFiles.
	 */
	public static function addWeeks(isStoryMode:Null<Bool>):Void
	{
		#if MODS_ALLOWED
		var entries:Array<VSliceSongEntry> = listSongs();

		if (isStoryMode != true)
		{
			for (e in entries)
			{
				var key:String = 'vslice-${e.mod}-${e.id}';
				if (WeekData.weeksLoaded.exists(key)) continue;
				makeWeek(key, e.mod, e.name, [[displayNameOf(e), iconFor(e.opponent), [146, 113, 253]]], diffsOf(e), false);
			}
		}

		if (isStoryMode != false)
			addLevelWeeks(entries);
		#end
	}

	static function addLevelWeeks(entries:Array<VSliceSongEntry>):Void
	{
		#if MODS_ALLOWED
		var mods:Array<String> = [];
		for (e in entries)
			if (!mods.contains(e.mod)) mods.push(e.mod);

		for (mod in mods)
		{
			var dir:String = Paths.mods('$mod/data/levels');
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;

			for (file in FileSystem.readDirectory(dir))
			{
				if (!file.endsWith('.json')) continue;

				var level:Dynamic = readJson('$dir/$file');
				if (level == null) continue;
				var levelId:String = file.substr(0, file.length - 5);

				var songsArr:Array<Dynamic> = [];
				var diffs:Array<String> = null;
				var ids:Array<String> = g(level, 'songs', []);
				for (id in ids)
				{
					var found:VSliceSongEntry = null;
					for (cand in entries)
						if (cand.mod == mod && cand.id == id)
						{
							found = cand;
							break;
						}
					if (found == null) continue;

					songsArr.push([displayNameOf(found), iconFor(found.opponent), [146, 113, 253]]);

					var d:Array<String> = diffsOf(found);
					diffs = (diffs == null) ? d : [for (x in diffs) if (d.contains(x)) x]; // solo las comunes
				}
				if (songsArr.length == 0) continue;
				if (diffs == null || diffs.length == 0) diffs = ['Normal'];

				var title:String = g(level, 'name', g(level, 'title', levelId));

				// StoryMenuState carga la imagen `storymenu/<clave de la semana>`; V-Slice la define en
				// `titleAsset` ("storymenu/titles/week1"), así que se usa ese nombre como clave si está libre.
				var key:String = 'vslice-$mod-$levelId';
				var titleAsset:String = g(level, 'titleAsset', '');
				if (titleAsset.startsWith('storymenu/'))
				{
					var k:String = titleAsset.substr('storymenu/'.length);
					if (k.length > 0 && !WeekData.weeksLoaded.exists(k)) key = k;
				}
				if (WeekData.weeksLoaded.exists(key)) continue;

				makeWeek(key, mod, title, songsArr, diffs, true);
			}
		}
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

				for (v in vars)
				{
					var vMetaPath:String = '$root/$song/$song-metadata-$v.json';
					if (!FileSystem.exists(vMetaPath)) continue;
					var vMeta:Dynamic = readJson(vMetaPath);
					if (vMeta == null) continue;
					var vp:Dynamic = g(vMeta, 'playData', {});
					var vd:Array<String> = [for (d in (g(vp, 'difficulties', []) : Array<String>)) d];
					result.push({id: '$song-$v', name: g(vMeta, 'songName', '$song-$v'), artist: g(vMeta, 'artist', ''), mod: mod, opponent: g(g(vp, 'characters', {}), 'opponent', 'dad'), difficulties: vd, variations: []});
				}
			}
		}
		#end
		return result;
	}
}
