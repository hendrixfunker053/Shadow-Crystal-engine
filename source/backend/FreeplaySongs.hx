package backend;

import flixel.util.FlxColor;
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
}
