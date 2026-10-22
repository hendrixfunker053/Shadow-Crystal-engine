
package backend;

import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef MenuItemData =
{
	var id:String;
	var image:String;
	var action:String;
	@:optional var args:String;

	// Opciones personalizadas
	@:optional var label:String;
	@:optional var column:String;
	@:optional var enabled:Bool;

	// Script asociado a esta opción
	@:optional var script:String;
}

typedef MainMenuFile =
{
	var items:Array<MenuItemData>;
	@:optional var left:MenuItemData;
	@:optional var right:MenuItemData;
	@:optional var spacing:Float;
	@:optional var startY:Float;

	// Personalización visual
	@:optional var custom:Bool;
	@:optional var background:String;
	@:optional var checker:Bool;
	@:optional var checkerAlpha:Float;

	// Scripts opcionales del menú
	@:optional var luaScripts:Array<String>;
	@:optional var hscriptScripts:Array<String>;
}

class MainMenuData
{
	public static function newItem(id:String, action:String):MenuItemData
	{
		return {
			id: id,
			image: 'mainmenu/menu_$id',
			action: action,
			args: '',
			label: id,
			column: 'CENTER',
			enabled: true
		};
	}

	public static function getDefault():MainMenuFile
	{
		var items:Array<MenuItemData> = [
			newItem('story_mode', 'story_mode'),
			newItem('freeplay', 'freeplay')
		];

		#if MODS_ALLOWED
		items.push(newItem('mods', 'mods'));
		#end

		items.push(newItem('credits', 'credits'));

		return {
			items: items,
			left: newItem('options', 'options'),
			right:
				#if ACHIEVEMENTS_ALLOWED
				newItem('achievements', 'achievements')
				#else
				null
				#end,
			spacing: 150,
			startY: 40,
			custom: false,
			background: 'menuBG',
			checker: true,
			checkerAlpha: 0.20,
			luaScripts: [],
			hscriptScripts: []
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
				file = cast Json.parse(raw);
			}
			catch (e:Dynamic)
			{
				trace('mainmenu.json inválido: $e');
			}
		}

		if (file == null || file.items == null || file.items.length < 1)
			file = getDefault();

		if (file.spacing == null)
			file.spacing = 150;

		if (file.startY == null)
			file.startY = 40;

		if (file.custom == null)
			file.custom = false;

		if (file.background == null)
			file.background = 'menuBG';

		if (file.checker == null)
			file.checker = true;

		if (file.checkerAlpha == null)
			file.checkerAlpha = 0.20;

		if (file.luaScripts == null)
			file.luaScripts = [];

		if (file.hscriptScripts == null)
			file.hscriptScripts = [];

		var all:Array<MenuItemData> = file.items.copy();

		if (file.left != null)
			all.push(file.left);

		if (file.right != null)
			all.push(file.right);

		for (item in all)
		{
			if (item.args == null)
				item.args = '';

			if (item.action == null)
				item.action = 'none';

			if (item.label == null)
				item.label = item.id;

			if (item.column == null)
				item.column = 'CENTER';

			if (item.enabled == null)
				item.enabled = true;
		}

		return file;
	}

	public static function save(file:MainMenuFile):String
	{
		#if sys
		var dir:String =
			(Mods.currentModDirectory != null
			&& Mods.currentModDirectory.length > 0)
			? Paths.mods(Mods.currentModDirectory + '/data')
			: Paths.mods('data');

		if (!FileSystem.exists(dir))
			FileSystem.createDirectory(dir);

		var path:String = dir + '/mainmenu.json';

		File.saveContent(
			path,
			Json.stringify(file, null, '\t')
		);

		return path;
		#else
		return null;
		#end
	}
}
