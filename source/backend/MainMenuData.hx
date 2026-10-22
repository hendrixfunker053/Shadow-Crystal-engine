package backend;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef MenuItemData = {
	id:String,      // prefijo de animación: "<id> idle" / "<id> selected"
	image:String,   // ruta del atlas, ej: mainmenu/menu_story_mode
	action:String,  // story_mode, freeplay, mods, achievements, credits, options, url, state, none
	?args:String    // url o nombre de clase (states.X)
}

typedef MainMenuFile = {
	items:Array<MenuItemData>,
	?left:MenuItemData,
	?right:MenuItemData,
	?spacing:Float,
	?startY:Float
}

class MainMenuData
{
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
			try { file = Json.parse(raw); }
			catch (e) trace('mainmenu.json inválido: $e');
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

	public static function save(file:MainMenuFile):String
	{
		#if sys
		var dir:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			? Paths.mods(Mods.currentModDirectory + '/data')
			: Paths.mods('data');
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		var path:String = dir + '/mainmenu.json';
		File.saveContent(path, Json.stringify(file, null, '\t'));
		return path;
		#else
		return null;
		#end
	}
}
