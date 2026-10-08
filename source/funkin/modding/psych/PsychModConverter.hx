package funkin.modding.psych;

#if sys
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

typedef ConvertedNotes =
{
  notes:Array<Dynamic>,
  timeChanges:Array<Dynamic>,
  focusEvents:Array<Dynamic>
};

/**
 * Converts Psych Engine mod folders into Polymod mods, in place, the first time the game sees them.
 *
 * A folder is treated as a Psych mod when it contains a `pack.json` and has no `_polymod_meta.json`.
 *
 * What it converts:
 * - `data/<song>/<song>[-difficulty].json` -> `data/songs/<id>/<id>-metadata.json` + `<id>-chart.json`
 * - `weeks/<week>.json` -> `data/levels/<week>.json`
 * - `pack.json` -> `_polymod_meta.json`
 *
 * What it leaves alone (Polymod already reads these paths the same way):
 * - `songs/<id>/Inst.ogg` and `Voices.ogg`
 * - `images/`, `sounds/`, `music/`, `videos/`
 *
 * Psych events are saved next to the chart as `<id>-psych-events.json`, so a script can consume them.
 * To force a mod to be converted again, delete its `_psych_converted` file.
 */
class PsychModConverter
{
  static final MARKER:String = '_psych_converted';

  static final STRUMLINE_SIZE:Int = 4;

  static final DIFFICULTY_ORDER:Array<String> = ['easy', 'normal', 'hard'];

  /**
   * Psych stage ids -> this game's stage ids.
   */
  static final STAGE_MAP:Map<String, String> = [
    'stage' => 'mainStage',
    'spooky' => 'spookyMansion',
    'philly' => 'phillyTrain',
    'limo' => 'limoRide',
    'mall' => 'mallXmas',
    'mallEvil' => 'mallEvil',
    'school' => 'school',
    'schoolEvil' => 'schoolEvil',
    'tank' => 'tankmanBattlefield'
  ];

  /**
   * Scans the mods folder and converts every unconverted Psych mod.
   * Never throws: a broken mod is logged and skipped.
   */
  public static function convertAll(modRoot:String):Void
  {
    if (!FileSystem.exists(modRoot) || !FileSystem.isDirectory(modRoot)) return;

    for (entry in FileSystem.readDirectory(modRoot))
    {
      var modDir:String = Path.join([modRoot, entry]);
      if (!FileSystem.isDirectory(modDir)) continue;
      if (!isPsychMod(modDir)) continue;

      try
      {
        convertMod(modDir, entry);
      }
      catch (e:Dynamic)
      {
        trace('[PsychCompat] Failed to convert "$entry": $e');
      }
    }
  }

  static function isPsychMod(modDir:String):Bool
  {
    if (!FileSystem.exists(Path.join([modDir, 'pack.json']))) return false;
    if (FileSystem.exists(Path.join([modDir, '_polymod_meta.json']))) return false;
    if (FileSystem.exists(Path.join([modDir, MARKER]))) return false;
    return true;
  }

  static function convertMod(modDir:String, modName:String):Void
  {
    trace('[PsychCompat] Converting Psych mod "$modName"...');

    var pack:Dynamic = readJson(Path.join([modDir, 'pack.json']));

    // 1. Songs
    var convertedSongs:Array<String> = [];
    var dataDir:String = Path.join([modDir, 'data']);
    if (FileSystem.exists(dataDir) && FileSystem.isDirectory(dataDir))
    {
      for (songFolder in FileSystem.readDirectory(dataDir))
      {
        // Ignore folders that already belong to this game's own layout.
        if (songFolder == 'songs' || songFolder == 'levels') continue;
        if (!FileSystem.isDirectory(Path.join([dataDir, songFolder]))) continue;

        var id:Null<String> = null;
        try
        {
          id = convertSong(modDir, songFolder);
        }
        catch (e:Dynamic)
        {
          trace('[PsychCompat]   Song "$songFolder" failed: $e');
        }
        if (id != null) convertedSongs.push(id);
      }
    }

    // 2. Weeks
    var weeksDir:String = Path.join([modDir, 'weeks']);
    if (FileSystem.exists(weeksDir) && FileSystem.isDirectory(weeksDir))
    {
      for (file in FileSystem.readDirectory(weeksDir))
      {
        if (!file.endsWith('.json')) continue;
        try
        {
          convertWeek(modDir, Path.join([weeksDir, file]), file.substr(0, file.length - 5), convertedSongs);
        }
        catch (e:Dynamic)
        {
          trace('[PsychCompat]   Week "$file" failed: $e');
        }
      }
    }

    // 3. Mod metadata. Written last, so a crash above leaves the mod unconverted.
    var title:String = fieldOr(pack, 'name', modName);
    writeJson(Path.join([modDir, '_polymod_meta.json']),
      {
        title: title,
        description: fieldOr(pack, 'description', 'Converted from a Psych Engine mod.'),
        contributors: [{name: 'Unknown'}],
        api_version: PolymodHandler.API_VERSION,
        mod_version: '1.0.0',
        license: 'All Rights Reserved'
      });

    File.saveContent(Path.join([modDir, MARKER]), 'Converted ' + Date.now().toString() + '\n');
    trace('[PsychCompat] "$modName": ${convertedSongs.length} song(s) converted.');
  }

  // ---------------------------------------------------------------------------
  // SONGS
  // ---------------------------------------------------------------------------

  /**
   * @return The converted song's id, or null if nothing usable was found.
   */
  static function convertSong(modDir:String, songFolder:String):Null<String>
  {
    var songDataDir:String = Path.join([modDir, 'data', songFolder]);
    var id:String = toId(songFolder);
    var folderLower:String = songFolder.toLowerCase();

    var charts:Map<String, Dynamic> = new Map();
    var eventsFile:Null<Dynamic> = null;

    for (file in FileSystem.readDirectory(songDataDir))
    {
      if (!file.endsWith('.json')) continue;
      var base:String = file.substr(0, file.length - 5);
      var baseLower:String = base.toLowerCase();

      if (baseLower == 'events')
      {
        eventsFile = readJson(Path.join([songDataDir, file]));
        continue;
      }

      var difficulty:String;
      if (baseLower == folderLower) difficulty = 'normal';
      else if (baseLower.startsWith(folderLower + '-')) difficulty = baseLower.substr(folderLower.length + 1);
      else
        continue;

      var parsed:Dynamic = readJson(Path.join([songDataDir, file]));
      var song:Dynamic = unwrapSong(parsed);
      if (song == null || !Std.isOfType(Reflect.field(song, 'notes'), Array)) continue;
      charts.set(difficulty, song);
    }

    var difficulties:Array<String> = [for (d in charts.keys()) d];
    if (difficulties.length == 0) return null;
    difficulties.sort(compareDifficulty);

    var main:Dynamic = charts.exists('normal') ? charts.get('normal') : charts.get(difficulties[0]);

    // Time changes come from the main chart.
    var timeChanges:Array<Dynamic> = [];
    var startBpm:Float = floatOr(main, 'bpm', 100.0);

    var notesByDifficulty:Dynamic = {};
    var scrollSpeeds:Dynamic = {};
    var focusEvents:Array<Dynamic> = [];
    var psychEvents:Array<Dynamic> = [];

    for (difficulty in difficulties)
    {
      var chart:Dynamic = charts.get(difficulty);
      var converted:ConvertedNotes = convertSections(chart, startBpm);

      Reflect.setField(notesByDifficulty, difficulty, converted.notes);
      Reflect.setField(scrollSpeeds, difficulty, floatOr(chart, 'speed', 1.0));

      if (chart == main)
      {
        timeChanges = converted.timeChanges;
        focusEvents = converted.focusEvents;
      }

      var chartEvents:Dynamic = Reflect.field(chart, 'events');
      if (chart == main && Std.isOfType(chartEvents, Array)) psychEvents = psychEvents.concat(cast chartEvents);
    }

    if (eventsFile != null)
    {
      var extra:Dynamic = Reflect.field(unwrapSong(eventsFile) ?? eventsFile, 'events');
      if (Std.isOfType(extra, Array)) psychEvents = psychEvents.concat(cast extra);
    }

    var outDir:String = Path.join([modDir, 'data', 'songs', id]);

    var ratings:Dynamic = {};
    for (difficulty in difficulties) Reflect.setField(ratings, difficulty, 1);

    var stage:String = fieldOr(main, 'stage', 'stage');
    var girlfriend:String = fieldOr(main, 'gfVersion', fieldOr(main, 'player3', 'gf'));

    writeJson(Path.join([outDir, '$id-metadata.json']),
      {
        version: '2.2.4',
        songName: fieldOr(main, 'song', songFolder),
        artist: 'Unknown',
        charter: 'Unknown',
        divisions: 96,
        looped: false,
        playData: {
          songVariations: [],
          difficulties: difficulties,
          characters: {
            player: fieldOr(main, 'player1', 'bf'),
            girlfriend: girlfriend,
            opponent: fieldOr(main, 'player2', 'dad'),
            instrumental: ''
          },
          stage: STAGE_MAP.exists(stage) ? STAGE_MAP.get(stage) : stage,
          noteStyle: 'funkin',
          ratings: ratings,
          previewStart: 0,
          previewEnd: 0
        },
        generatedBy: 'PsychModConverter',
        timeFormat: 'ms',
        timeChanges: timeChanges
      });

    writeJson(Path.join([outDir, '$id-chart.json']),
      {
        version: '2.0.0',
        scrollSpeed: scrollSpeeds,
        events: focusEvents,
        notes: notesByDifficulty,
        generatedBy: 'PsychModConverter'
      });

    if (psychEvents.length > 0)
    {
      writeJson(Path.join([outDir, '$id-psych-events.json']), psychEvents);
    }

    trace('[PsychCompat]   Song "$songFolder" -> "$id" (${difficulties.join(", ")})');
    return id;
  }

  static function convertSections(chart:Dynamic, startBpm:Float):ConvertedNotes
  {
    var result:ConvertedNotes =
      {
        notes: [],
        timeChanges: [{t: 0, bpm: startBpm}],
        focusEvents: []
      };

    var sections:Array<Dynamic> = cast Reflect.field(chart, 'notes');
    var bpm:Float = startBpm;
    var sectionStart:Float = 0;
    var lastFocus:Int = -1;

    for (i in 0...sections.length)
    {
      var section:Dynamic = sections[i];
      if (section == null) continue;

      if (Reflect.field(section, 'changeBPM') == true && floatOr(section, 'bpm', 0) > 0)
      {
        bpm = floatOr(section, 'bpm', bpm);
        if (i > 0) result.timeChanges.push({t: sectionStart, bpm: bpm});
      }

      var mustHit:Bool = Reflect.field(section, 'mustHitSection') == true;
      var gfSection:Bool = Reflect.field(section, 'gfSection') == true;

      // Camera focus, placed at the start of the section like Psych does.
      var focus:Int = gfSection ? 2 : (mustHit ? 0 : 1);
      if (focus != lastFocus)
      {
        lastFocus = focus;
        result.focusEvents.push({t: sectionStart, e: 'FocusCamera', v: {char: focus}});
      }

      var sectionNotes:Dynamic = Reflect.field(section, 'sectionNotes');
      if (Std.isOfType(sectionNotes, Array))
      {
        for (raw in (cast sectionNotes : Array<Dynamic>))
        {
          if (!Std.isOfType(raw, Array)) continue;
          var n:Array<Dynamic> = cast raw;
          if (n.length < 2) continue;

          var time:Float = toFloat(n[0]);
          var data:Int = Std.int(toFloat(n[1]));
          if (data < 0) continue; // Old-format event notes.

          data = data % (STRUMLINE_SIZE * 2);

          // Same rule as the legacy format: when it isn't a must-hit section, the halves swap.
          if (!mustHit) data = (data >= STRUMLINE_SIZE) ? data - STRUMLINE_SIZE : data + STRUMLINE_SIZE;

          var note:Dynamic = {t: time, d: data};
          var length:Float = (n.length > 2) ? toFloat(n[2]) : 0;
          if (length > 0) Reflect.setField(note, 'l', length);

          var kind:String = (n.length > 3 && Std.isOfType(n[3], String)) ? (n[3] : String) : '';
          if (kind == 'Alt Animation') kind = 'alt';
          if (kind != '') Reflect.setField(note, 'k', kind);

          result.notes.push(note);
        }
      }

      var beats:Float = floatOr(section, 'sectionBeats', 4);
      sectionStart += beats * 60000.0 / bpm;
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // WEEKS
  // ---------------------------------------------------------------------------

  static function convertWeek(modDir:String, weekPath:String, weekId:String, convertedSongs:Array<String>):Void
  {
    var week:Dynamic = readJson(weekPath);
    if (week == null) return;

    var songs:Array<String> = [];
    var rawSongs:Dynamic = Reflect.field(week, 'songs');
    if (Std.isOfType(rawSongs, Array))
    {
      for (entry in (cast rawSongs : Array<Dynamic>))
      {
        if (!Std.isOfType(entry, Array)) continue;
        var songId:String = toId(Std.string((entry : Array<Dynamic>)[0]));
        if (convertedSongs.contains(songId)) songs.push(songId);
      }
    }
    if (songs.length == 0) return;

    // Psych keeps the title graphic at images/storymenu/<week>.png.
    var titleAsset:String = 'storymenu/titles/week1';
    var psychTitle:String = Path.join([modDir, 'images', 'storymenu', '$weekId.png']);
    if (FileSystem.exists(psychTitle))
    {
      var targetDir:String = Path.join([modDir, 'images', 'storymenu', 'titles']);
      ensureDir(targetDir);
      File.copy(psychTitle, Path.join([targetDir, '$weekId.png']));
      titleAsset = 'storymenu/titles/$weekId';
    }

    writeJson(Path.join([modDir, 'data', 'levels', '$weekId.json']),
      {
        version: '1.0.2',
        name: fieldOr(week, 'storyName', fieldOr(week, 'weekName', weekId)),
        titleAsset: titleAsset,
        props: [],
        visible: Reflect.field(week, 'hideStoryMode') != true,
        songs: songs,
        background: '#F9CF51'
      });

    trace('[PsychCompat]   Week "$weekId" -> level with ${songs.length} song(s)');
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  /**
   * Psych 0.x wraps the chart in `{"song": {...}}`, while newer versions put everything at the root.
   */
  static function unwrapSong(parsed:Dynamic):Dynamic
  {
    if (parsed == null) return null;
    var inner:Dynamic = Reflect.field(parsed, 'song');
    if (inner != null && !Std.isOfType(inner, String)) return inner;
    return parsed;
  }

  static function toId(name:String):String
  {
    return name.toLowerCase().replace(' ', '-');
  }

  static function compareDifficulty(a:String, b:String):Int
  {
    var ia:Int = DIFFICULTY_ORDER.indexOf(a);
    var ib:Int = DIFFICULTY_ORDER.indexOf(b);
    if (ia != -1 && ib != -1) return ia - ib;
    if (ia != -1) return -1;
    if (ib != -1) return 1;
    return (a < b) ? -1 : ((a > b) ? 1 : 0);
  }

  static function toFloat(value:Dynamic):Float
  {
    if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) return cast value;
    var parsed:Float = Std.parseFloat(Std.string(value));
    return Math.isNaN(parsed) ? 0 : parsed;
  }

  static function floatOr(obj:Dynamic, key:String, fallback:Float):Float
  {
    if (obj == null) return fallback;
    var value:Dynamic = Reflect.field(obj, key);
    if (value == null) return fallback;
    var parsed:Float = toFloat(value);
    return parsed;
  }

  static function fieldOr(obj:Dynamic, key:String, fallback:String):String
  {
    if (obj == null) return fallback;
    var value:Dynamic = Reflect.field(obj, key);
    if (value == null) return fallback;
    var text:String = Std.string(value);
    return (text == '') ? fallback : text;
  }

  /**
   * Psych files sometimes have a BOM or stray bytes after the closing brace.
   */
  static function readJson(path:String):Dynamic
  {
    try
    {
      var text:String = File.getContent(path);
      if (text.length > 0 && text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
      var last:Int = text.lastIndexOf('}');
      if (last != -1) text = text.substr(0, last + 1);
      return Json.parse(text);
    }
    catch (e:Dynamic)
    {
      trace('[PsychCompat] Could not parse "$path": $e');
      return null;
    }
  }

  static function writeJson(path:String, data:Dynamic):Void
  {
    ensureDir(Path.directory(path));
    File.saveContent(path, Json.stringify(data, null, '  '));
  }

  static function ensureDir(dir:String):Void
  {
    if (dir == '' || FileSystem.exists(dir)) return;
    ensureDir(Path.directory(dir));
    FileSystem.createDirectory(dir);
  }
}
#end
