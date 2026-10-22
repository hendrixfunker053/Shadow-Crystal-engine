package backend;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef MenuItemData =
{
	id:String, // prefijo de animación: "<id> idle" / "<id> selected"
	image:String, // ruta del atlas, ej: mainmenu/menu_story_mode
	action:String, // story_mode, freeplay, mods, achievements, credits, options, url, state, none
	?args:String // url o nombre de clase (states.X)
}

typedef MainMenuFile =
{
	items:Array<MenuItemData>,
	?left:MenuItemData,
	?right:MenuItemData,
	?spacing:Float,
	?startY:Float
}

class MainMenuData
{
	/** Claves aceptadas en pack.json para activar el menú custom (y con él, el panel rápido). */
	static final CUSTOM_MENU_KEYS:Array<String> = ['Custom menu', 'custom menu', 'Custom Menu', 'customMenu', 'custom_menu'];

	public static function newItem(id:String, action:String):MenuItemData
		return {id: id, image: 'mainmenu/menu_$id', action: action, args: ''};

	public static function getDefault():MainMenuFile
	{
		var items:Array<MenuItemData> = [newItem('story_mode', 'story_mode'), newItem('freeplay', 'freeplay')];
		#if MODS_ALLOWED
		items.push(newItem('mods', 'mods'));
		#end
		items.push(newItem('credits', 'credits'));

		return {
			items: items,
			left: newItem('options', 'options'),
			right: #if ACHIEVEMENTS_ALLOWED newItem('achievements', 'achievements') #else null #end,
			spacing: 150,
			startY: 40
		};
	}

	public static function load():MainMenuFile
	{
		var file:MainMenuFile = null;
		var raw:String = Paths.getTextFromFile('data/mainmenu.json');
		if (raw != null)
		{
			try
			{
				file = Json.parse(raw);
			}
			catch (e)
				trace('mainmenu.json inválido: $e');
		}
		if (file == null || file.items == null || file.items.length < 1)
			file = getDefault();

		if (file.spacing == null) file.spacing = 150;
		if (file.startY == null) file.startY = 40;

		var all:Array<MenuItemData> = file.items.copy();
		if (file.left != null) all.push(file.left);
		if (file.right != null) all.push(file.right);
		for (i in all)
		{
			if (i.args == null) i.args = '';
			if (i.action == null) i.action = 'none';
		}
		return file;
	}

	static function modDataDir():String
	{
		var folder:String = Mods.currentModDirectory;
		return (folder != null && folder.length > 0) ? Paths.mods(folder + '/data') : Paths.mods('data');
	}

	public static function save(file:MainMenuFile):String
	{
		#if sys
		var dir:String = modDataDir();
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		var path:String = dir + '/mainmenu.json';
		File.saveContent(path, Json.stringify(file, null, '\t'));
		return path;
		#else
		return null;
		#end
	}

	// ------------------------------------------------------------------ pack.json

	static function packPath():String
	{
		var folder:String = Mods.currentModDirectory;
		if (folder == null || folder.length < 1) return null;
		return Paths.mods(folder + '/pack.json');
	}

	static function isTrue(v:Dynamic):Bool
	{
		if (v == null) return false;
		if (Std.isOfType(v, Bool)) return v == true;
		if (Std.isOfType(v, Int) || Std.isOfType(v, Float)) return v != 0;
		var s:String = Std.string(v).toLowerCase();
		return s == 'true' || s == '1' || s == 'yes';
	}

	/**
	 * true si el pack.json del mod actual tiene  "Custom menu": true.
	 * Cuando es true, el menú principal muestra el panel rápido.
	 */
	public static function hasCustomMenu():Bool
	{
		#if (MODS_ALLOWED && sys)
		var path:String = packPath();
		if (path == null || !FileSystem.exists(path)) return false;

		try
		{
			var pack:Dynamic = Json.parse(File.getContent(path));
			for (key in CUSTOM_MENU_KEYS)
				if (Reflect.hasField(pack, key))
					return isTrue(Reflect.field(pack, key));
		}
		catch (e)
			trace('pack.json inválido: $e');
		#end
		return false;
	}

	/** Escribe "Custom menu" en el pack.json del mod actual (lo crea si no existe, respetando el resto de claves). */
	public static function setCustomMenu(value:Bool):String
	{
		#if (MODS_ALLOWED && sys)
		var path:String = packPath();
		if (path == null) return null;

		var pack:Dynamic = {};
		if (FileSystem.exists(path))
		{
			try
			{
				pack = Json.parse(File.getContent(path));
			}
			catch (e)
			{
				trace('pack.json inválido, no se modifica: $e');
				return null;
			}
		}
		else
		{
			pack = {name: Mods.currentModDirectory, description: '', restart: false, runsGlobally: false};
		}

		// Quitar variantes antiguas para no duplicar la clave
		for (key in CUSTOM_MENU_KEYS)
			Reflect.deleteField(pack, key);
		Reflect.setField(pack, 'Custom menu', value);

		var dir:String = haxe.io.Path.directory(path);
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent(path, Json.stringify(pack, null, '\t'));
		return path;
		#else
		return null;
		#end
	}
}
