package backend;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef MenuItemData =
{
	id:String, // prefijo de animación: "<id> idle" / "<id> selected"
	image:String, // ruta del atlas, ej: mainmenu/menu_story_mode
	action:String, // story_mode, freeplay, mods, achievements, credits, options, url, state, script, none
	?args:String, // url, clase (states.X) o nombre de la función para la acción "script"
	?x:Null<Float>, // posición absoluta opcional (anula el layout automático)
	?y:Null<Float>,
	?scale:Null<Float>
}

typedef MainMenuFile =
{
	items:Array<MenuItemData>,
	?left:MenuItemData,
	?right:MenuItemData,
	?spacing:Float,
	?startY:Float
}

/**
 * Menús custom (Options / FreePlay / Credits). Se manejan como Dynamic porque el editor
 * los edita por nombre de campo. Estructura de cada archivo:
 *   options_menu.json  { enabled, entries:[{label, action, args}] }
 *   freeplay_menu.json { enabled, bg, songs:[{name, icon, color, difficulties, mod}] }
 *   credits_menu.json  { enabled, entries:[{name, desc, icon, color, url, header}] }
 */
class MainMenuData
{
	/** Claves aceptadas en pack.json para activar el menú custom (y con él, el panel rápido). */
	static final CUSTOM_MENU_KEYS:Array<String> = ['Custom menu', 'custom menu', 'Custom Menu', 'customMenu', 'custom_menu'];

	/** Acciones válidas por menú (el editor las muestra en el dropdown). */
	public static final MAIN_ACTIONS:Array<String> = [
		'story_mode', 'freeplay', 'mods', 'achievements', 'credits', 'options', 'url', 'state', 'script', 'none'
	];
	public static final OPTION_ACTIONS:Array<String> = [
		'notes', 'controls', 'adjust_delay', 'graphics', 'visuals', 'gameplay', 'mobile', 'state', 'substate', 'url', 'script'
	];

	/** Clases candidatas para cada acción de Options (se usa la primera que exista en tu build). */
	public static final OPTION_CLASSES:Map<String, Array<String>> = [
		'notes' => ['options.NotesSubState'],
		'controls' => ['options.ControlsSubState'],
		'graphics' => ['options.GraphicsSettingsSubState'],
		'visuals' => ['options.VisualsSettingsSubState', 'options.VisualsUISubState'],
		'gameplay' => ['options.GameplaySettingsSubState'],
		'mobile' => ['options.MobileOptionsSubState', 'mobile.options.MobileOptionsSubState'],
		'adjust_delay' => ['options.NoteOffsetState']
	];

	/** true tras pulsar "Exit mod" en el panel rápido: menú original, sin panel, sin scripts ni menús custom. Se apaga al volver al Title. */
	public static var forceOriginal:Bool = false;

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
		if (forceOriginal) return getDefault();

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

	/**
	 * Layout del menú principal (lo usan MainMenuState y el editor para que coincidan).
	 * k = factor de escala (el editor lo usa para la vista previa). Los sprites ya deben tener su tamaño final.
	 */
	public static function place(file:MainMenuFile, center:Array<FlxSprite>, left:FlxSprite, right:FlxSprite, w:Float, h:Float, isMobile:Bool,
			k:Float = 1):Void
	{
		var startY:Float = file.startY * k;
		var spacing:Float = file.spacing * k;

		for (n => s in center)
		{
			s.x = (w - s.width) / 2;
			s.y = startY + n * spacing;
		}

		var story:FlxSprite = center.length > 0 ? center[0] : null;
		if (right != null && story != null)
		{
			right.x = isMobile ? w - right.width - 16 * k : Math.min(story.x + story.width + 40 * k, w - right.width - 20 * k);
			right.y = startY + (story.height - right.height) / 2;
		}
		if (left != null)
		{
			left.x = 36 * k;
			left.y = h - left.height - 50 * k;
		}

		for (n => s in center) applyOverride(file.items[n], s, k);
		if (left != null) applyOverride(file.left, left, k);
		if (right != null) applyOverride(file.right, right, k);
	}

	static function applyOverride(d:MenuItemData, s:FlxSprite, k:Float):Void
	{
		if (d == null || s == null) return;
		if (d.x != null) s.x = d.x * k;
		if (d.y != null) s.y = d.y * k;
	}

	static function modDataDir():String
	{
		var folder:String = Mods.currentModDirectory;
		return (folder != null && folder.length > 0) ? Paths.mods(folder + '/data') : Paths.mods('data');
	}

	static function modRootDir():String
	{
		var folder:String = Mods.currentModDirectory;
		return (folder != null && folder.length > 0) ? Paths.mods(folder) : Paths.mods('');
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

	// ------------------------------------------------------------------ Options / FreePlay / Credits custom

	public static function customFileName(kind:String):String
		return 'data/${kind}_menu.json';

	public static function listKeyOf(kind:String):String
		return kind == 'freeplay' ? 'songs' : 'entries';

	public static function defaultCustom(kind:String):Dynamic
	{
		return switch (kind)
		{
			case 'options':
				{
					enabled: false,
					entries: [
						{label: 'Notes', action: 'notes', args: ''},
						{label: 'Controls', action: 'controls', args: ''},
						{label: 'Adjust Delay and Combo', action: 'adjust_delay', args: ''},
						{label: 'Graphics', action: 'graphics', args: ''},
						{label: 'Visuals', action: 'visuals', args: ''},
						{label: 'Gameplay', action: 'gameplay', args: ''},
						{label: 'Mobile Options', action: 'mobile', args: ''}
					]
				};
			case 'freeplay':
				{
					enabled: false,
					bg: '',
					songs: [{name: 'Tutorial', icon: 'gf', color: '#FF9AD1', difficulties: 'normal', mod: ''}]
				};
			default:
				{
					enabled: false,
					entries: [
						{name: 'Equipo del mod', header: true, desc: '', icon: '', color: '#FFFFFF', url: ''},
						{name: 'Tu nombre', header: false, desc: 'Creador del mod', icon: '', color: '#FF9AD1', url: ''}
					]
				};
		}
	}

	/** Lee data/<kind>_menu.json del mod; si no existe o está roto devuelve el de por defecto (enabled:false). */
	public static function loadCustom(kind:String):Dynamic
	{
		var data:Dynamic = null;
		var raw:String = Paths.getTextFromFile(customFileName(kind));
		if (raw != null)
		{
			try
			{
				data = Json.parse(raw);
			}
			catch (e)
				trace('${customFileName(kind)} inválido: $e');
		}
		if (data == null || !Std.isOfType(Reflect.field(data, listKeyOf(kind)), Array))
			data = defaultCustom(kind);
		if (Reflect.field(data, 'enabled') == null) Reflect.setField(data, 'enabled', false);
		return data;
	}

	public static function saveCustom(kind:String, data:Dynamic):String
	{
		#if sys
		var dir:String = modDataDir();
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		var path:String = dir + '/${kind}_menu.json';
		File.saveContent(path, Json.stringify(data, null, '\t'));
		return path;
		#else
		return null;
		#end
	}

	/** true si el mod tiene data/<kind>_menu.json con "enabled": true y al menos una entrada. */
	public static function customEnabled(kind:String):Bool
	{
		if (forceOriginal) return false;
		var raw:String = Paths.getTextFromFile(customFileName(kind));
		if (raw == null) return false;
		try
		{
			var d:Dynamic = Json.parse(raw);
			var list:Array<Dynamic> = Reflect.field(d, listKeyOf(kind));
			return isTrue(Reflect.field(d, 'enabled')) && list != null && list.length > 0;
		}
		catch (e)
			return false;
	}

	public static function parseColor(s:String, def:FlxColor = FlxColor.WHITE):FlxColor
	{
		if (s == null || s.length < 1) return def;
		var c:Null<FlxColor> = FlxColor.fromString(s.charAt(0) == '#' ? s : '#' + s);
		return c == null ? def : c;
	}

	/** Busca la primera clase existente entre varios nombres (también prueba con prefijo states.). */
	public static function resolveClassAny(names:Array<String>):Class<Dynamic>
	{
		for (n in names)
		{
			if (n == null || n.length < 1) continue;
			var c:Class<Dynamic> = Type.resolveClass(n);
			if (c == null) c = Type.resolveClass('states.' + n);
			if (c != null) return c;
		}
		return null;
	}

	// ------------------------------------------------------------------ scripts (Lua / HScript)

	/** Archivos .lua / .hx de scripts/<kind>/ (mod actual y mods globales). kind: mainmenu, options, freeplay, credits. */
	public static function scriptFiles(kind:String):Array<String>
	{
		var found:Array<String> = [];
		#if (sys && MODS_ALLOWED)
		var dirs:Array<String> = [Paths.mods('scripts/$kind')];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			dirs.insert(0, Paths.mods(Mods.currentModDirectory + '/scripts/$kind'));
		for (g in Mods.getGlobalMods())
			dirs.push(Paths.mods(g + '/scripts/$kind'));

		for (d in dirs)
		{
			if (!FileSystem.exists(d) || !FileSystem.isDirectory(d)) continue;
			var files:Array<String> = FileSystem.readDirectory(d);
			files.sort(function(a, b) return a < b ? -1 : 1);
			for (f in files)
			{
				var low:String = f.toLowerCase();
				if (low.endsWith('.lua') || low.endsWith('.hx'))
					if (!found.contains(d + '/' + f)) found.push(d + '/' + f);
			}
		}
		#end
		return found;
	}

	/** Crea una plantilla de script en el mod actual. Devuelve la ruta (o null si ya existía / no se pudo). */
	public static function createScriptTemplate(kind:String, lua:Bool):String
	{
		#if (sys && MODS_ALLOWED)
		var dir:String = modRootDir() + '/scripts/$kind';
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		var path:String = dir + '/${kind}_ejemplo.' + (lua ? 'lua' : 'hx');
		if (FileSystem.exists(path)) return null;
		File.saveContent(path, scriptTemplate(kind, lua));
		return path;
		#else
		return null;
		#end
	}

	public static function scriptTemplate(kind:String, lua:Bool):String
	{
		var hooks:String = switch (kind)
		{
			case 'options': 'onSelect(index, label) / onAccept(index, action, args) / onBack()';
			case 'freeplay': 'onSelect(index, song) / onDifficultyChange(diff) / onAccept(index, song, diff) / onBack()';
			case 'credits': 'onSelect(index, name) / onAccept(index, name, url) / onBack()';
			default: 'onSelect(column, index) / onAccept(action, id, index) / onMenuAction(name, id) / onBack()';
		};
		var accept:String = switch (kind)
		{
			case 'options': 'index, action, args';
			case 'freeplay': 'index, song, diff';
			case 'credits': 'index, name, url';
			default: 'action, id, index';
		};

		if (lua)
			return '-- Script de $kind (Lua). Hooks: onCreate / onCreatePost / onUpdate(elapsed) / onUpdatePost(elapsed) / $hooks
-- Devuelve Function_Stop en onAccept para cancelar la accion por defecto.
-- Funciones: makeLuaText, addLuaText, makeLuaSprite, makeAnimatedLuaSprite, addAnimationByPrefix, playAnim, addLuaSprite,
-- removeLuaSprite, setProperty, getProperty, setTextString, doTweenX/Y/Alpha/Angle, runTimer, playSound, playMusic,
-- switchState, openUrl, keyJustPressed, getItemCount, getSelectedItem, setSelectedItem, debugPrint

function onCreatePost()
	makeLuaText(\'saludo\', \'Hola desde Lua\', 600, 20, 20)
	addLuaText(\'saludo\')
end

function onAccept($accept)
	return Function_Continue
end
';
		return '// Script de $kind (HScript). Hooks: onCreate / onCreatePost / onUpdate(elapsed) / onUpdatePost(elapsed) / $hooks
// Devuelve Function_Stop en onAccept para cancelar la accion por defecto.
// Variables: game (el state), getItems(), selectItem(i), switchState(nombre), openUrl(url), debugPrint(txt)

function onCreatePost()
{
	var t = new FlxText(20, 20, 600, \'Hola desde HScript\', 32);
	t.scrollFactor.set();
	add(t);
}

function onAccept($accept)
{
	return Function_Continue;
}
';
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
		if (forceOriginal) return false;
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
