package backend;

import flixel.util.FlxColor;
import states.LoadingState;
import states.PlayState;
import states.StoryMenuState;

typedef FreeplaySong =
{
	name:String,
	icon:String,
	color:Int, // FlxColor
	difficulties:String, // "Easy,Normal,Hard"
	folder:String, // carpeta del mod ('' = juego base)
	week:Int
}

/**
 * Detecta las canciones de FreePlay a partir de las weeks (igual que el FreeplayState original),
 * sin listas manuales. includeOtherMods = false deja solo las canciones del mod actual.
 */
class FreeplaySongs
{
	public static final DEFAULT_DIFFICULTIES:String = 'Easy,Normal,Hard';

	static function isLocked(w:WeekData):Bool
	{
		return (!w.startUnlocked && w.weekBefore != null && w.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(w.weekBefore) || !StoryMenuState.weekCompleted.get(w.weekBefore)));
	}

	public static function load(includeOtherMods:Bool, exclude:String = ''):Array<FreeplaySong>
	{
		var out:Array<FreeplaySong> = [];

		var banned:Array<String> = [];
		if (exclude != null)
			for (e in exclude.split(','))
			{
				var t:String = e.trim();
				if (t.length > 0) banned.push(Paths.formatToSongPath(t));
			}

		var currentMod:String = Mods.currentModDirectory == null ? '' : Mods.currentModDirectory;

		WeekData.reloadWeekFiles(false);
		for (i in 0...WeekData.weeksList.length)
		{
			var w:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			if (w == null || w.hideFreeplay || isLocked(w)) continue;

			var folder:String = w.folder == null ? '' : w.folder;
			if (!includeOtherMods && folder != currentMod) continue;

			var diffs:String = (w.difficulties != null && w.difficulties.trim().length > 0) ? w.difficulties.trim() : DEFAULT_DIFFICULTIES;

			for (s in w.songs)
			{
				var name:String = Std.string(s[0]);
				if (banned.contains(Paths.formatToSongPath(name))) continue;

				var c:Array<Int> = s[2];
				if (c == null || c.length < 3) c = [146, 113, 253];

				out.push({
					name: name,
					icon: Std.string(s[1]),
					color: FlxColor.fromRGB(c[0], c[1], c[2]),
					difficulties: diffs,
					folder: folder,
					week: i
				});
			}
		}

		Mods.currentModDirectory = currentMod; // reloadWeekFiles puede cambiarlo
		return out;
	}

	public static function hex(c:Int):String
		return '#' + StringTools.hex(c & 0xFFFFFF, 6);

	/** Lista de dificultades (con la primera en mayúscula, como usa Difficulty). */
	public static function diffList(raw:String):Array<String>
	{
		var out:Array<String> = [];
		for (d in (raw == null ? '' : raw).split(','))
		{
			var t:String = d.trim();
			if (t.length > 0) out.push(t.charAt(0).toUpperCase() + t.substr(1));
		}
		if (out.length < 1) out.push('Normal');
		return out;
	}

	/** Índice de la dificultad por defecto ("Normal") o 0. */
	public static function defaultDiff(list:Array<String>):Int
	{
		var i:Int = list.indexOf('Normal');
		return i >= 0 ? i : 0;
	}

	/**
	 * Inicia una canción (flujo del FreeplayState de Psych 1.0.x). Devuelve false si no se pudo cargar.
	 * Si tu fork cambió Song / Highscore / Difficulty / LoadingState, ajusta aquí.
	 */
	public static function start(s:FreeplaySong, diffIndex:Int):Bool
	{
		var diffs:Array<String> = diffList(s.difficulties);
		if (diffIndex < 0 || diffIndex >= diffs.length) diffIndex = defaultDiff(diffs);

		#if MODS_ALLOWED
		Mods.currentModDirectory = s.folder; // '' para el juego base
		#end

		var songLowercase:String = Paths.formatToSongPath(s.name);
		Difficulty.list = diffs;
		PlayState.storyWeek = s.week;
		var poop:String = Highscore.formatSong(songLowercase, diffIndex);

		try
		{
			Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = diffIndex;
		}
		catch (err:Dynamic)
		{
			trace('No se pudo cargar la canción "$songLowercase" ($poop): $err');
			return false;
		}

		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			Paths.freeGraphicsFromMemory();

		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		if (FlxG.sound.music != null) FlxG.sound.music.volume = 0;
		return true;
	}

	/**
	 * Funciones de FreePlay para los scripts de states propios (Lua y HScript):
	 * loadFreeplaySongs(incluirOtrosMods, ocultar) -> cantidad, getSongCount, getSongName(i), getSongIcon(i),
	 * getSongColor(i) ("#RRGGBB"), getSongFolder(i), getSongDifficulties(i) ("Easy,Normal,Hard"), startSong(i, dificultad).
	 */
	public static function registerExtras(x:Map<String, Dynamic>):Void
	{
		var songs:Array<FreeplaySong> = [];
		var ok = function(i:Int) return i >= 0 && i < songs.length;

		x.set('loadFreeplaySongs', function(includeOtherMods:Bool = false, exclude:String = '') {
			songs = load(includeOtherMods, exclude);
			return songs.length;
		});
		x.set('getSongCount', function() return songs.length);
		x.set('getSongName', function(i:Int) return ok(i) ? songs[i].name : '');
		x.set('getSongIcon', function(i:Int) return ok(i) ? songs[i].icon : '');
		x.set('getSongColor', function(i:Int) return ok(i) ? hex(songs[i].color) : '#FFFFFF');
		x.set('getSongFolder', function(i:Int) return ok(i) ? songs[i].folder : '');
		x.set('getSongDifficulties', function(i:Int) return ok(i) ? diffList(songs[i].difficulties).join(',') : '');
		x.set('getSongScore', function(i:Int, diff:Int = 0) return ok(i) ? Highscore.getScore(songs[i].name, diff) : 0);
		// HScript: devuelve un HealthIcon listo para add(). En Lua no se puede devolver el objeto.
		x.set('makeSongIcon', function(i:Int) {
			if (!ok(i)) return null;
			var prev:String = Mods.currentModDirectory;
			Mods.currentModDirectory = songs[i].folder; // el icono se busca en la carpeta de su mod
			var icon:objects.HealthIcon = new objects.HealthIcon(songs[i].icon);
			Mods.currentModDirectory = prev;
			return icon;
		});
		x.set('startSong', function(i:Int, diff:Int = -1) return ok(i) ? start(songs[i], diff) : false);
	}
}
