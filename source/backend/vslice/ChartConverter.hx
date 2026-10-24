package backend.vslice;

import haxe.Json;
import backend.vslice.VSliceMods.g;

/**
 * Convierte `<id>-metadata.json` + `<id>-chart.json` (V-Slice) al JSON de canción de Psych (`psych_v1`).
 *
 * Reglas de conversión:
 *  - V-Slice: `d` 0-3 = jugador, 4-7 = oponente (fijo). Psych depende de `mustHitSection`,
 *    así que cada nota se reasigna a la columna correcta según la sección.
 *  - `FocusCamera` al inicio de sección -> `mustHitSection` / `gfSection`.
 *    Si cae a mitad de sección se conserva como evento `vslice:FocusCamera`.
 *  - Eventos sin equivalente directo pasan como `vslice:<Nombre>` con los datos en JSON
 *    en `value1`, para que un script/hook de PlayState los maneje.
 *  - Secciones de 4 beats. Si un cambio de BPM no cae al inicio de un compás, se aplica
 *    en la siguiente sección.
 */
class ChartConverter
{
	static inline var SECTION_BEATS:Int = 4;

	public static function convert(songId:String, metaStr:String, chartStr:String, difficulty:String):Dynamic
	{
		var meta:Dynamic = Json.parse(metaStr);
		var chart:Dynamic = Json.parse(chartStr);

		var rawNotes:Array<Dynamic> = g(g(chart, 'notes', {}), difficulty, null);
		if (rawNotes == null) return null; // esta variación no tiene esa dificultad

		var rawEvents:Array<Dynamic> = g(chart, 'events', []);

		// ---- BPM ----
		var tcs:Array<Dynamic> = g(meta, 'timeChanges', []);
		if (tcs.length == 0) tcs = [{t: 0, bpm: 100}];
		tcs.sort(function(a:Dynamic, b:Dynamic):Int return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

		// ---- Duración total ----
		var endMs:Float = 0;
		for (n in rawNotes)
			endMs = Math.max(endMs, n.t + g(n, 'l', 0));
		for (e in rawEvents)
			endMs = Math.max(endMs, e.t);

		// ---- Inicio y BPM de cada sección ----
		var starts:Array<Float> = [];
		var bpms:Array<Float> = [];
		var t:Float = 0;
		var cur:Float = tcs[0].bpm;
		var ti:Int = 1;
		do
		{
			while (ti < tcs.length && tcs[ti].t <= t + 1)
			{
				cur = tcs[ti].bpm;
				ti++;
			}
			starts.push(t);
			bpms.push(cur);
			t += SECTION_BEATS * 60000 / cur;
		}
		while (t <= endMs);

		// ---- Foco de cámara por sección ----
		var focus:Array<{t:Float, who:Int}> = [];
		for (e in rawEvents)
		{
			if (e.e != 'FocusCamera') continue;
			var v:Dynamic = e.v;
			var who:Int = Std.isOfType(v, Int) ? v : Std.int(g(v, 'char', 0));
			focus.push({t: e.t, who: who});
		}
		focus.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

		var sections:Array<Dynamic> = [];
		var fi:Int = 0;
		var curWho:Int = 0;
		for (i in 0...starts.length)
		{
			while (fi < focus.length && focus[fi].t <= starts[i] + 1)
			{
				curWho = focus[fi].who;
				fi++;
			}
			var notesList:Array<Dynamic> = [];
			sections.push({
				sectionNotes: notesList,
				sectionBeats: SECTION_BEATS,
				mustHitSection: curWho == 0,
				gfSection: curWho == 2,
				bpm: bpms[i],
				changeBPM: i > 0 && bpms[i] != bpms[i - 1],
				altAnim: false
			});
		}

		// ---- Notas ----
		for (n in rawNotes)
		{
			var sec:Dynamic = sections[sectionAt(starts, n.t)];
			var d:Int = Std.int(n.d);
			var isPlayer:Bool = d < 4;
			var lane:Int = ((d % 4) + 4) % 4;
			var mustHit:Bool = sec.mustHitSection;
			var psychData:Int = (isPlayer == mustHit) ? lane : lane + 4;

			var row:Array<Dynamic> = [n.t, psychData, g(n, 'l', 0)];
			var kind:Dynamic = g(n, 'k', null);
			if (kind != null && kind != '' && kind != 'normal') row.push(kind);
			sec.sectionNotes.push(row);
		}

		// ---- Eventos ----
		var events:Array<Dynamic> = [];
		var byTime:Map<String, Array<Dynamic>> = new Map();
		for (e in rawEvents)
		{
			var mapped:Array<Dynamic> = mapEvent(e, starts);
			if (mapped == null) continue;

			var key:String = Std.string(e.t);
			var bucket:Array<Dynamic> = byTime.get(key);
			if (bucket == null)
			{
				bucket = [];
				byTime.set(key, bucket);
				events.push([e.t, bucket]);
			}
			bucket.push(mapped);
		}

		// ---- Datos de la canción ----
		var play:Dynamic = g(meta, 'playData', {});
		var chars:Dynamic = g(play, 'characters', {});
		var player:String = g(chars, 'player', 'bf');
		var opponent:String = g(chars, 'opponent', 'dad');

		var speeds:Dynamic = g(chart, 'scrollSpeed', {});
		var speed:Float = g(speeds, difficulty, g(speeds, 'default', 1.0));

		// Psych busca el audio con formatToSongPath(song); si no coincide con el id, usamos el id.
		var songName:String = g(meta, 'songName', songId);
		if (Paths.formatToSongPath(songName) != songId) songName = songId;

		return {
			song: songName,
			vsliceId: songId,
			notes: sections,
			events: events,
			bpm: tcs[0].bpm,
			needsVoices: true,
			speed: speed,
			offset: g(g(meta, 'offsets', {}), 'instrumental', 0),
			player1: player,
			player2: opponent,
			gfVersion: g(chars, 'girlfriend', 'gf'),
			stage: mapStage(g(play, 'stage', 'mainStage')),
			format: 'psych_v1',
			// Extras para las siguientes fases (audio por personaje, estilo de notas, etc.)
			vsliceInst: g(chars, 'instrumental', ''),
			vsliceVocals: {
				player: g(chars, 'playerVocals', [player]),
				opponent: g(chars, 'opponentVocals', [opponent])
			},
			vsliceNoteStyle: g(play, 'noteStyle', 'funkin')
		};
	}

	/** Psych y V-Slice nombran distinto algunos stages base. Los de mods pasan igual. */
	static function mapStage(stage:String):String
	{
		return switch (stage)
		{
			case 'mainStage': 'stage';
			case 'spookyMansion': 'spooky';
			case 'phillyTrain': 'philly';
			case 'limoRide': 'limo';
			case 'mallXmas': 'mall';
			case 'tankmanBattlefield': 'tank';
			default: stage;
		}
	}

	static function sectionAt(starts:Array<Float>, time:Float):Int
	{
		var i:Int = starts.length - 1;
		while (i > 0 && starts[i] > time + 1)
			i--;
		return i;
	}

	/** Devuelve [nombre, value1, value2] de Psych, o null si el evento ya se absorbió en la sección. */
	static function mapEvent(e:Dynamic, starts:Array<Float>):Array<Dynamic>
	{
		var name:String = e.e;
		var v:Dynamic = g(e, 'v', {});

		switch (name)
		{
			case 'FocusCamera':
				// Al inicio de sección ya se aplicó en mustHitSection/gfSection.
				if (Math.abs(e.t - starts[sectionAt(starts, e.t)]) <= 1) return null;

			case 'PlayAnimation':
				var target:String = Std.string(g(v, 'target', 'dad')).toLowerCase();
				if (target == 'boyfriend') target = 'bf';
				if (target == 'girlfriend') target = 'gf';
				return ['Play Animation', g(v, 'anim', 'idle'), target];
		}

		return ['vslice:$name', Json.stringify(v), ''];
	}
}
