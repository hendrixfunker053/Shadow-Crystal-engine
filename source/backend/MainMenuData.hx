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
 * Datos del menú principal (data/mainmenu.json), descubrimiento de scripts y plantillas.
 * Los demás menús (Options, FreePlay, Credits...) se hacen con scripts en scripts/states/ y scripts/substates/.
 */
class MainMenuData
{
	/** Claves aceptadas en pack.json para activar el menú custom (y con él, el panel rápido). */
	static final CUSTOM_MENU_KEYS:Array<String> = ['Custom menu', 'custom menu', 'Custom Menu', 'customMenu', 'custom_menu'];

	/** Acciones válidas del menú principal (el editor las muestra en el dropdown). */
	public static final MAIN_ACTIONS:Array<String> = [
		'story_mode', 'freeplay', 'mods', 'achievements', 'credits', 'options', 'url', 'state', 'substate', 'script', 'none'
	];

	/**
	 * true tras pulsar "Exit mod" en el panel rápido: menú original, sin panel ni scripts.
	 * Se mantiene al volver al Title y entrar otra vez (toda la sesión), y se apaga si cambias de mod
	 * o con el aviso "Volver al menú del mod" que sale en el menú original.
	 */
	public static var forceOriginal(get, set):Bool;

	static var _forceOriginal:Bool = false;
	static var _exitedMod:String = '';

	static function currentModName():String
		return Mods.currentModDirectory == null ? '' : Mods.currentModDirectory;

	static function get_forceOriginal():Bool
		return _forceOriginal && (_exitedMod == '' || currentModName() == '' || _exitedMod == currentModName());

	static function set_forceOriginal(v:Bool):Bool
	{
		_forceOriginal = v;
		_exitedMod = currentModName();
		return v;
	}

	/**
	 * true si el mod trae scripts/states/<name>.lua|.hx para REEMPLAZAR un state original
	 * (TitleState, MainMenuState, StoryMenuState, FreeplayState, CreditsState, OptionsState, ModsMenuState).
	 * Siempre false tras "Exit mod".
	 */
	public static function overridden(name:String):Bool
		return !forceOriginal && stateScriptExists('states', name);

	/**
	 * true si el menú principal actual es "custom": el mod trae scripts/states/MainMenuState, o data/mainmenu.json,
	 * o scripts/mainmenu/*, o su pack.json tiene "Custom menu": true. Siempre false tras "Exit mod".
	 * Con esto se decide si se dibuja el panel rápido (en MainMenuState Y en ScriptedState('MainMenuState')).
	 */
	public static function isCustomMainMenu():Bool
	{
		if (forceOriginal) return false;
		if (stateScriptExists('states', 'MainMenuState')) return true;
		if (scriptFiles('mainmenu').length > 0) return true;
		if (Paths.getTextFromFile('data/mainmenu.json') != null) return true;
		return hasCustomMenu();
	}

	/** Cambia al state `name` si el mod lo reemplaza con un script; si no, al que devuelva `fallback`. */
	public static function goState(name:String, fallback:Void->MusicBeatState):Void
	{
		if (overridden(name)) MusicBeatState.switchState(new states.ScriptedState(name));
		else MusicBeatState.switchState(fallback());
	}

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
			if (c == null) c = Type.resolveClass('options.' + n); // OptionsState vive en options.*
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

	/** Scripts de un state/substate propio: scripts/<kind>/<name>.lua|.hx y todo lo que haya en scripts/<kind>/<name>/. kind: states | substates. */
	public static function stateScriptFiles(kind:String, name:String):Array<String>
	{
		var found:Array<String> = [];
		#if (sys && MODS_ALLOWED)
		if (name == null || name.length < 1) return found;

		var dirs:Array<String> = [Paths.mods('scripts/$kind')];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			dirs.insert(0, Paths.mods(Mods.currentModDirectory + '/scripts/$kind'));
		for (g in Mods.getGlobalMods())
			dirs.push(Paths.mods(g + '/scripts/$kind'));

		for (d in dirs)
		{
			for (ext in ['.lua', '.hx'])
				if (FileSystem.exists(d + '/' + name + ext) && !found.contains(d + '/' + name + ext))
					found.push(d + '/' + name + ext);

			var sub:String = d + '/' + name;
			if (FileSystem.exists(sub) && FileSystem.isDirectory(sub))
			{
				var files:Array<String> = FileSystem.readDirectory(sub);
				files.sort(function(a, b) return a < b ? -1 : 1);
				for (f in files)
				{
					var low:String = f.toLowerCase();
					if ((low.endsWith('.lua') || low.endsWith('.hx')) && !found.contains(sub + '/' + f))
						found.push(sub + '/' + f);
				}
			}
		}
		#end
		return found;
	}

	public static function stateScriptExists(kind:String, name:String):Bool
		return stateScriptFiles(kind, name).length > 0;

	static function cleanName(name:String):String
	{
		var out:String = '';
		for (i in 0...name.length)
		{
			var c:String = name.charAt(i);
			if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_') out += c;
		}
		return out;
	}

	/** Crea scripts/mainmenu/mainmenu_ejemplo.lua|.hx en el mod actual. Devuelve la ruta (o null si ya existía). */
	public static function createScriptTemplate(lua:Bool):String
	{
		#if (sys && MODS_ALLOWED)
		var dir:String = modRootDir() + '/scripts/mainmenu';
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		var path:String = dir + '/mainmenu_ejemplo.' + (lua ? 'lua' : 'hx');
		if (FileSystem.exists(path)) return null;
		File.saveContent(path, mainMenuTemplate(lua));
		return path;
		#else
		return null;
		#end
	}

	/** Crea scripts/<kind>/<name>.lua|.hx (kind: states | substates). Devuelve la ruta (o null si ya existía / nombre vacío). */
	public static function createStateTemplate(kind:String, name:String, lua:Bool):String
	{
		#if (sys && MODS_ALLOWED)
		name = cleanName(name == null ? '' : name);
		if (name.length < 1) return null;

		var dir:String = modRootDir() + '/scripts/$kind';
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		var path:String = dir + '/' + name + (lua ? '.lua' : '.hx');
		if (FileSystem.exists(path)) return null;
		File.saveContent(path, stateTemplate(kind, name, lua));
		return path;
		#else
		return null;
		#end
	}

	static function mainMenuTemplate(lua:Bool):String
	{
		if (lua)
			return "-- Script del menu principal (Lua). Hooks: onCreate / onCreatePost / onUpdate(elapsed) / onUpdatePost(elapsed)
-- onSelect(columna, index) / onAccept(action, id, index) / onMenuAction(nombre, id) / onBack()
-- onAccept puede devolver Function_Stop para cancelar la accion por defecto.
-- Un item con accion 'script' llama a onMenuAction(args, id). Con accion 'state' / 'substate' y args = nombre
-- abre scripts/states/<nombre> o scripts/substates/<nombre>.

function onCreatePost()
	makeLuaText('saludo', 'Hola desde Lua', 600, 20, 20)
	addLuaText('saludo')
end

function onAccept(action, id, index)
	return Function_Continue
end
";
		return "// Script del menu principal (HScript). Hooks: onCreate / onCreatePost / onUpdate(elapsed) / onUpdatePost(elapsed)
// onSelect(columna, index) / onAccept(action, id, index) / onMenuAction(nombre, id) / onBack()
// onAccept puede devolver Function_Stop para cancelar la accion por defecto.
// Variables: game, getItems(), selectItem(i), switchState(nombre), openSubState(nombre), openUrl(url), debugPrint(txt)

function onCreatePost()
{
	var t = new FlxText(20, 20, 600, 'Hola desde HScript', 32);
	t.scrollFactor.set();
	add(t);
}

function onAccept(action, id, index)
{
	return Function_Continue;
}
";
	}

	static function stateTemplate(kind:String, name:String, lua:Bool):String
	{
		var isSub:Bool = kind == 'substates';
		var what:String = isSub ? 'SubState' : 'State';
		var open:String = isSub ? "openSubState('" + name + "')" : "switchState('" + name + "')";
		var closeNote:String = isSub ? 'closeState() cierra el substate.' : 'closeState() vuelve al menu principal.';

		if (lua)
			return "-- " + what + " propio '" + name + "' (Lua). Abrelo desde un item del menu principal: accion '" + (isSub ? 'substate' : 'state') + "', args '" + name + "'.
-- Tambien desde cualquier script con " + open + ".
-- Hooks: onCreate / onCreatePost / onUpdate(elapsed) / onUpdatePost(elapsed) / onBack() / onDestroy()
-- onBack puede devolver Function_Stop para no usar la salida por defecto. " + closeNote + "
-- Objetos disponibles: bg (fondo). Funciones: makeLuaText, addLuaText, makeLuaSprite, makeAnimatedLuaSprite, addAnimationByPrefix,
-- playAnim, addLuaSprite, removeLuaSprite, setProperty, getProperty, setTextString, doTweenX/Y/Alpha/Angle, runTimer, playSound,
-- playMusic, switchState, openSubState, openUrl, keyJustPressed, closeState, debugPrint.
-- Canciones (FreePlay propio): loadFreeplaySongs(incluirOtrosMods, ocultar), getSongCount, getSongName(i), getSongIcon(i),
-- getSongColor(i), getSongFolder(i), getSongDifficulties(i), startSong(i, dificultad).

local options = {'Opcion 1', 'Opcion 2', 'Volver'}
local cur = 0

function refresh()
	for i = 0, #options - 1 do
		setProperty('opt' .. i .. '.alpha', i == cur and 1 or 0.5)
	end
end

function onCreatePost()
	for i = 0, #options - 1 do
		makeLuaText('opt' .. i, options[i + 1], 600, 100, 150 + i * 60)
		addLuaText('opt' .. i)
	end
	refresh()
end

function onUpdate(elapsed)
	if keyJustPressed('UP') then cur = (cur - 1) % #options; refresh() end
	if keyJustPressed('DOWN') then cur = (cur + 1) % #options; refresh() end
	if keyJustPressed('ENTER') then
		if cur == #options - 1 then closeState() else debugPrint(options[cur + 1]) end
	end
end
";
		return "// " + what + " propio '" + name + "' (HScript). Abrelo desde un item del menu principal: accion '" + (isSub ? 'substate' : 'state') + "', args '" + name + "'.
// Tambien desde cualquier script con " + open + ".
// Hooks: onCreate / onCreatePost / onUpdate(elapsed) / onUpdatePost(elapsed) / onBack() / onDestroy()
// onBack puede devolver Function_Stop para no usar la salida por defecto. " + closeNote + "
// Variables: game, bg (fondo), closeState(), switchState(nombre), openSubState(nombre), openUrl(url), debugPrint(txt)
// Canciones (FreePlay propio): loadFreeplaySongs(incluirOtrosMods, ocultar), getSongCount(), getSongName(i), getSongIcon(i),
// getSongColor(i), getSongFolder(i), getSongDifficulties(i), startSong(i, dificultad).

var options = ['Opcion 1', 'Opcion 2', 'Volver'];
var cur = 0;
var texts = [];

function refresh()
{
	for (i in 0...texts.length)
		texts[i].alpha = (i == cur) ? 1 : 0.5;
}

function onCreatePost()
{
	for (i in 0...options.length)
	{
		var t = new FlxText(100, 150 + i * 60, 600, options[i], 32);
		t.scrollFactor.set();
		add(t);
		texts.push(t);
	}
	refresh();
}

function onUpdate(elapsed)
{
	if (FlxG.keys.justPressed.UP) { cur = (cur + options.length - 1) % options.length; refresh(); }
	if (FlxG.keys.justPressed.DOWN) { cur = (cur + 1) % options.length; refresh(); }
	if (FlxG.keys.justPressed.ENTER)
	{
		if (cur == options.length - 1) closeState();
		else debugPrint(options[cur]);
	}
}
";
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
		// Mod actual y mods globales (si no hay mod seleccionado, un script/menú global también activa el panel)
		var folders:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) folders.push(Mods.currentModDirectory);
		for (g in Mods.getGlobalMods()) if (!folders.contains(g)) folders.push(g);

		for (f in folders)
		{
			var path:String = Paths.mods(f + '/pack.json');
			if (!FileSystem.exists(path)) continue;
			try
			{
				var pack:Dynamic = Json.parse(File.getContent(path));
				for (key in CUSTOM_MENU_KEYS)
					if (Reflect.hasField(pack, key) && isTrue(Reflect.field(pack, key)))
					{
						trace('Quick panel activado por $path');
						return true;
					}
			}
			catch (e)
				trace('pack.json inválido ($path): $e');
		}
		trace('Quick panel desactivado: ninguno de [' + folders.join(', ') + '] tiene "Custom menu": true en pack.json');
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
