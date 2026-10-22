package backend;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Persisted visual layout overrides for non-custom menus. Coordinates are optional. */
typedef MenuScreenLayoutFile = { ?backgroundX:Float, ?backgroundY:Float, ?backgroundScale:Float, ?itemsX:Float, ?itemsY:Float, ?itemSpacing:Float, ?itemScale:Float, ?scoreX:Float, ?scoreY:Float, ?difficultyX:Float, ?difficultyY:Float };

class MenuScreenLayout
{
  public static function defaults():MenuScreenLayoutFile return {backgroundX: 0, backgroundY: 0, backgroundScale: 1, itemsX: 0, itemsY: 0, itemSpacing: 92, itemScale: 1, scoreX: 0, scoreY: 0, difficultyX: 0, difficultyY: 0};

  static function path(menu:String):String
  {
    var folder:String = Mods.currentModDirectory;
    var root:String = (folder != null && folder.length > 0) ? Paths.mods(folder + '/data') : Paths.mods('data');
    return root + '/menu-layout-' + menu + '.json';
  }

  public static function load(menu:String):MenuScreenLayoutFile
  {
    var result:MenuScreenLayoutFile = defaults();
    var raw:String = Paths.getTextFromFile('data/menu-layout-' + menu + '.json');
    if (raw != null) try { result = cast Json.parse(raw); } catch (e:Dynamic) trace('Invalid menu layout (' + menu + '): ' + e);
    if (result.backgroundX == null) result.backgroundX = 0;
    if (result.backgroundY == null) result.backgroundY = 0;
    if (result.backgroundScale == null) result.backgroundScale = 1;
    if (result.itemsX == null) result.itemsX = 0;
    if (result.itemsY == null) result.itemsY = 0;
    if (result.itemSpacing == null) result.itemSpacing = 92;
    if (result.itemScale == null) result.itemScale = 1;
    if (result.scoreX == null) result.scoreX = 0;
    if (result.scoreY == null) result.scoreY = 0;
    if (result.difficultyX == null) result.difficultyX = 0;
    if (result.difficultyY == null) result.difficultyY = 0;
    return result;
  }

  public static function save(menu:String, layout:MenuScreenLayoutFile):String
  {
    #if sys
    var p:String = path(menu);
    var dir:String = haxe.io.Path.directory(p);
    if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
    File.saveContent(p, Json.stringify(layout, null, '\t'));
    return p;
    #else
    return null;
    #end
  }
}
