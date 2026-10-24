package backend;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end
#if sys
import sys.io.File;
#end

#if LUA_ALLOWED
private class LuaScript
{
	public var lua:State;
	public var name:String;

	public function new(lua:State, name:String)
	{
		this.lua = lua;
		this.name = name;
	}
}
#end

/**
 * Host de scripts (Lua y HScript) para los menús: MainMenuState, CustomOptionsState,
 * CustomFreeplayState y CustomCreditsState. Carga los .lua/.hx de mods/<mod>/scripts/<kind>/.
 *
 * Es independiente de PlayState/FunkinLua (en un menú no hay PlayState), por eso trae su propia API de Lua.
 * Hooks: onCreate, onCreatePost, onUpdate(elapsed), onUpdatePost(elapsed), onSelect, onAccept, onBack,
 * onDestroy, onTweenCompleted(tag), onTimerCompleted(tag, loops, loopsLeft) y los propios de cada menú.
 * Si un hook devuelve Function_Stop, call() devuelve true y el menú cancela su acción por defecto.
 */
class MenuScripts
{
	public static final FUNCTION_STOP:String = '##PSYCHLUA_FUNCTIONSTOP';
	public static final FUNCTION_CONTINUE:String = '##PSYCHLUA_FUNCTIONCONTINUE';

	public var owner:FlxState;
	public var kind:String;
	/** Para states/substates propios: nombre del script (scripts/<kind>/<only>.lua|.hx). */
	public var only:String;

	/** El menú que lo usa rellena estos tres para que los scripts puedan leer/mover la selección. */
	public var getItems:Void->Array<FlxObject>;
	public var selectItem:Int->Void;
	public var getSelected:Void->Int;

	var objects:Map<String, FlxObject> = new Map();
	var tweens:Map<String, FlxTween> = new Map();
	var timers:Map<String, FlxTimer> = new Map();
	var registered:Array<String> = [];

	#if LUA_ALLOWED
	var luas:Array<LuaScript> = [];
	#end
	#if HSCRIPT_ALLOWED
	var hscripts:Array<HScript> = [];
	#end

	public function new(owner:FlxState, kind:String, ?only:String)
	{
		this.owner = owner;
		this.kind = kind;
		this.only = only;
		getItems = function() return [];
		selectItem = function(i:Int) {};
		getSelected = function() return 0;
	}

	/** Funciones extra que el menú ofrece a los scripts (nombre -> función). Registrar ANTES de load(). */
	public var extras:Map<String, Dynamic> = new Map();

	/** Hace accesible un objeto del menú desde los scripts por su tag (setProperty('tag.x', ...)). */
	public function registerObject(tag:String, obj:FlxObject):Void
		objects.set(tag, obj);

	/** Carga los .lua / .hx. Se llama una vez que el menú dejó listos getItems/extras. */
	public function load():Void
	{
		if (!MainMenuData.forceOriginal) loadAll();
	}

	// ------------------------------------------------------------------ carga

	function loadAll():Void
	{
		var files:Array<String> = (only == null) ? MainMenuData.scriptFiles(kind) : MainMenuData.stateScriptFiles(kind, only);
		for (path in files)
		{
			var low:String = path.toLowerCase();
			#if LUA_ALLOWED
			if (low.endsWith('.lua')) loadLua(path);
			#end
			#if HSCRIPT_ALLOWED
			if (low.endsWith('.hx')) loadHScript(path);
			#end
		}
	}

	#if HSCRIPT_ALLOWED
	function loadHScript(path:String):Void
	{
		try
		{
			var vars:Dynamic = {
				game: owner,
				state: owner,
				scriptKind: kind,
				getItems: function() return getItems(),
				selectItem: function(i:Int) selectItem(i),
				getSelected: function() return getSelected(),
				switchState: switchStateByName,
				openSubState: openSubStateByName,
				openUrl: function(url:String) CoolUtil.browserLoad(url),
				debugPrint: function(text:Dynamic) trace('[$kind] ' + Std.string(text)),
				Function_Stop: FUNCTION_STOP,
				Function_Continue: FUNCTION_CONTINUE,
				add: function(o:FlxBasic) return owner.add(o),
				insert: function(i:Int, o:FlxBasic) return owner.insert(i, o),
				remove: function(o:FlxBasic) return owner.remove(o, true),
				controls: Controls.instance,
				exitMod: exitModNow,
				getModName: modName,
				setBPM: setBpmValue,
				controlPressed: controlDown,
				makeGraphic: makeGraphicObj,
				mobileBuild: #if mobile true #else false #end,
				playMenuMusic: playMenuMusic,
				skipTransition: skipTransition,
				tapJustPressed: tapJustPressed,
				tapOverlaps: tapOverlaps,
				tapConsume: tapConsume,
				wideFit: wideFit,
				textOutline: textOutline
			};
			// objetos registrados por el state (bg, ...) como variables del script
			for (k => o in objects) Reflect.setField(vars, k, o);
			for (k => f in extras) Reflect.setField(vars, k, f);
			// parent = null y file = ruta: HScript lee el archivo y lo ejecuta (parentInstance = FlxG.state)
			var hs:HScript = new HScript(null, path, vars);
			hscripts.push(hs);
		}
		catch (e:Dynamic)
			trace('Error cargando HScript $path: $e');
	}
	#end

	#if LUA_ALLOWED
	function loadLua(path:String):Void
	{
		var l:State = LuaL.newstate();
		LuaL.openlibs(l);
		Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call));

		set(l, 'Function_Stop', FUNCTION_STOP);
		set(l, 'Function_Continue', FUNCTION_CONTINUE);
		set(l, 'scriptKind', kind);
		set(l, 'screenWidth', FlxG.width);
		set(l, 'screenHeight', FlxG.height);
		set(l, 'mobileBuild', #if mobile true #else false #end);

		registerLuaFunctions(l);

		var result:Dynamic = LuaL.dofile(l, path);
		var resultStr:String = Lua.tostring(l, result);
		if (resultStr != null && result != 0)
		{
			trace('Error en Lua $path: $resultStr');
			Lua.close(l);
			return;
		}
		luas.push(new LuaScript(l, path));
	}

	static function set(l:State, name:String, value:Dynamic):Void
	{
		Convert.toLua(l, value);
		Lua.setglobal(l, name);
	}

	function cb(l:State, name:String, fn:Dynamic):Void
	{
		Lua_helper.add_callback(l, name, fn);
		if (!registered.contains(name)) registered.push(name);
	}

	function registerLuaFunctions(l:State):Void
	{
		cb(l, 'debugPrint', function(text:Dynamic) trace('[$kind] ' + Std.string(text)));

		// --- selección / items
		cb(l, 'getItemCount', function() return getItems().length);
		cb(l, 'getSelectedItem', function() return getSelected());
		cb(l, 'setSelectedItem', function(i:Int) selectItem(i));

		// --- propiedades (tag.x, item0.y, game.camera.zoom ...)
		cb(l, 'getProperty', function(path:String) return getProp(path));
		cb(l, 'setProperty', function(path:String, value:Dynamic) return setProp(path, value));
		cb(l, 'scaleObject', function(tag:String, x:Float, y:Float, updateHitbox:Bool = true)
		{
			var o:Dynamic = getObj(tag);
			if (o == null || !Std.isOfType(o, FlxSprite)) return;
			var s:FlxSprite = cast o;
			s.scale.set(x, y);
			if (updateHitbox) s.updateHitbox();
		});

		// --- sprites
		cb(l, 'makeLuaSprite', function(tag:String, image:String = '', x:Float = 0, y:Float = 0)
		{
			removeObj(tag, true);
			var s:FlxSprite = new FlxSprite(x, y);
			if (image != null && image.length > 0) s.loadGraphic(Paths.image(image));
			s.antialiasing = ClientPrefs.data.antialiasing;
			s.scrollFactor.set();
			objects.set(tag, s);
		});
		cb(l, 'makeAnimatedLuaSprite', function(tag:String, image:String, x:Float = 0, y:Float = 0)
		{
			removeObj(tag, true);
			var s:FlxSprite = new FlxSprite(x, y);
			s.frames = Paths.getSparrowAtlas(image);
			s.antialiasing = ClientPrefs.data.antialiasing;
			s.scrollFactor.set();
			objects.set(tag, s);
		});
		cb(l, 'addAnimationByPrefix', function(tag:String, name:String, prefix:String, fps:Float = 24, loop:Bool = true)
		{
			var o:Dynamic = getObj(tag);
			if (o != null && Std.isOfType(o, FlxSprite)) (cast o : FlxSprite).animation.addByPrefix(name, prefix, fps, loop);
		});
		cb(l, 'playAnim', function(tag:String, name:String, force:Bool = false)
		{
			var o:Dynamic = getObj(tag);
			if (o != null && Std.isOfType(o, FlxSprite)) (cast o : FlxSprite).animation.play(name, force);
		});
		cb(l, 'addLuaSprite', function(tag:String, front:Bool = false)
		{
			var o:FlxObject = objects.get(tag);
			if (o == null) return;
			if (front) owner.add(o);
			else owner.insert(0, o);
		});
		cb(l, 'removeLuaSprite', function(tag:String, destroy:Bool = true) removeObj(tag, destroy));

		// --- texto
		cb(l, 'makeLuaText', function(tag:String, text:String = '', width:Int = 500, x:Float = 0, y:Float = 0)
		{
			removeObj(tag, true);
			var t:FlxText = new FlxText(x, y, width, text, 32);
			t.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.scrollFactor.set();
			objects.set(tag, t);
		});
		cb(l, 'addLuaText', function(tag:String)
		{
			var o:FlxObject = objects.get(tag);
			if (o != null) owner.add(o);
		});
		cb(l, 'setTextString', function(tag:String, text:String)
		{
			var o:Dynamic = getObj(tag);
			if (o != null && Std.isOfType(o, FlxText)) (cast o : FlxText).text = text;
		});
		cb(l, 'setTextSize', function(tag:String, size:Int)
		{
			var o:Dynamic = getObj(tag);
			if (o != null && Std.isOfType(o, FlxText)) (cast o : FlxText).size = size;
		});
		cb(l, 'setTextColor', function(tag:String, color:String)
		{
			var o:Dynamic = getObj(tag);
			if (o != null && Std.isOfType(o, FlxText)) (cast o : FlxText).color = MainMenuData.parseColor(color);
		});

		// --- tweens / timers
		cb(l, 'doTweenX', function(tag:String, obj:String, v:Float, d:Float, ease:String = 'linear') doTween(tag, obj, {x: v}, d, ease));
		cb(l, 'doTweenY', function(tag:String, obj:String, v:Float, d:Float, ease:String = 'linear') doTween(tag, obj, {y: v}, d, ease));
		cb(l, 'doTweenAlpha', function(tag:String, obj:String, v:Float, d:Float, ease:String = 'linear') doTween(tag, obj, {alpha: v}, d, ease));
		cb(l, 'doTweenAngle', function(tag:String, obj:String, v:Float, d:Float, ease:String = 'linear') doTween(tag, obj, {angle: v}, d, ease));
		cb(l, 'cancelTween', function(tag:String)
		{
			var t:FlxTween = tweens.get(tag);
			if (t != null) t.cancel();
			tweens.remove(tag);
		});
		cb(l, 'runTimer', function(tag:String, time:Float = 1, loops:Int = 1)
		{
			var old:FlxTimer = timers.get(tag);
			if (old != null) old.cancel();
			timers.set(tag, new FlxTimer().start(time, function(t:FlxTimer) call('onTimerCompleted', [tag, t.loops, t.loopsLeft]), loops));
		});
		cb(l, 'cancelTimer', function(tag:String)
		{
			var t:FlxTimer = timers.get(tag);
			if (t != null) t.cancel();
			timers.remove(tag);
		});

		// --- audio / navegación / input
		cb(l, 'playSound', function(name:String, volume:Float = 1) FlxG.sound.play(Paths.sound(name), volume));
		cb(l, 'playMusic', function(name:String, volume:Float = 1, loop:Bool = true) FlxG.sound.playMusic(Paths.music(name), volume, loop));
		cb(l, 'switchState', function(name:String) return switchStateByName(name));
		cb(l, 'openSubState', function(name:String) return openSubStateByName(name));
		cb(l, 'openUrl', function(url:String) CoolUtil.browserLoad(url));
		cb(l, 'keyJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name.toUpperCase()) == true);
		cb(l, 'keyPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name.toUpperCase()) == true);
		cb(l, 'getMouseX', function() return FlxG.mouse.screenX);
		cb(l, 'getMouseY', function() return FlxG.mouse.screenY);
		cb(l, 'mouseClicked', function() return FlxG.mouse.justPressed);

		// --- mod / state / input comunes
		cb(l, 'exitMod', function() exitModNow());
		cb(l, 'getModName', function() return modName());
		cb(l, 'setBPM', function(bpm:Float) setBpmValue(bpm));
		cb(l, 'controlPressed', function(name:String) return controlDown(name));
		cb(l, 'makeGraphic', function(tag:String, width:Int, height:Int, color:String = '#FFFFFF') { makeGraphicObj(tag, width, height, color); });

		cb(l, 'playMenuMusic', function(name:String, volume:Float = 1) playMenuMusic(name, volume));
		cb(l, 'skipTransition', function() skipTransition());
		cb(l, 'tapJustPressed', function() return tapJustPressed());
		cb(l, 'tapConsume', function() tapConsume());
		cb(l, 'tapOverlapsObject', function(tag:String)
		{
			var o:Dynamic = getObj(tag);
			return o != null && Std.isOfType(o, FlxSprite) && tapOverlaps(cast o);
		});

		// --- funciones propias de cada menú (FreePlay: getSongName, startSelectedSong...)
		for (k => f in extras) cb(l, k, f);
	}
	#end

	// ------------------------------------------------------------------ llamadas

	/** Llama a `fn` en todos los scripts. Devuelve true si alguno devolvió Function_Stop. */
	public function call(fn:String, ?args:Array<Dynamic>):Bool
	{
		if (args == null) args = [];
		var stop:Bool = false;

		#if LUA_ALLOWED
		for (s in luas)
		{
			var r:Dynamic = callLua(s, fn, args);
			if (r == FUNCTION_STOP) stop = true;
		}
		#end

		#if HSCRIPT_ALLOWED
		for (h in hscripts)
		{
			try
			{
				if (!h.exists(fn)) continue;
				var cv:Dynamic = h.call(fn, args);
				var rv:Dynamic = null;
				if (cv != null)
				{
					rv = Reflect.field(cv, 'returnValue');
					if (rv == null) rv = Reflect.field(cv, 'methodReturn');
				}
				if (rv == FUNCTION_STOP) stop = true;
			}
			catch (e:Dynamic)
				trace('Error en HScript ($fn): $e');
		}
		#end

		return stop;
	}

	#if LUA_ALLOWED
	function callLua(s:LuaScript, fn:String, args:Array<Dynamic>):Dynamic
	{
		var l:State = s.lua;
		if (l == null) return FUNCTION_CONTINUE;

		Lua.getglobal(l, fn);
		if (Lua.type(l, -1) != Lua.LUA_TFUNCTION)
		{
			Lua.pop(l, 1);
			return FUNCTION_CONTINUE;
		}

		for (a in args) Convert.toLua(l, a);
		var status:Int = Lua.pcall(l, args.length, 1, 0);
		if (status != Lua.LUA_OK)
		{
			trace('Error en Lua ${s.name} ($fn): ' + Lua.tostring(l, -1));
			Lua.pop(l, 1);
			return FUNCTION_CONTINUE;
		}

		var r:Dynamic = cast Convert.fromLua(l, -1);
		Lua.pop(l, 1);
		return r;
	}
	#end

	// ------------------------------------------------------------------ utilidades

	function getObj(name:String):Dynamic
	{
		if (objects.exists(name)) return objects.get(name);
		if (name == 'game') return owner;
		if (name.startsWith('item'))
		{
			var n:Null<Int> = Std.parseInt(name.substr(4));
			var items:Array<FlxObject> = getItems();
			if (n != null && n >= 0 && n < items.length) return items[n];
		}
		return null;
	}

	function getProp(path:String):Dynamic
	{
		var parts:Array<String> = path.split('.');
		var o:Dynamic = getObj(parts[0]);
		var start:Int = 1;
		if (o == null) { o = owner; start = 0; }
		for (i in start...parts.length)
		{
			if (o == null) return null;
			o = Reflect.getProperty(o, parts[i]);
		}
		return o;
	}

	function setProp(path:String, value:Dynamic):Bool
	{
		var parts:Array<String> = path.split('.');
		var o:Dynamic = getObj(parts[0]);
		var start:Int = 1;
		if (o == null) { o = owner; start = 0; }
		for (i in start...parts.length - 1)
		{
			if (o == null) return false;
			o = Reflect.getProperty(o, parts[i]);
		}
		if (o == null) return false;
		Reflect.setProperty(o, parts[parts.length - 1], value);
		return true;
	}

	function removeObj(tag:String, destroy:Bool):Void
	{
		var o:FlxObject = objects.get(tag);
		if (o == null) return;
		owner.remove(o, true);
		if (destroy) o.destroy();
		objects.remove(tag);
	}

	function doTween(tag:String, objName:String, props:Dynamic, duration:Float, ease:String):Void
	{
		var o:Dynamic = getObj(objName);
		if (o == null) return;

		var old:FlxTween = tweens.get(tag);
		if (old != null) old.cancel();

		var easeFn:Dynamic = Reflect.field(FlxEase, ease);
		if (easeFn == null) easeFn = FlxEase.linear;

		tweens.set(tag, FlxTween.tween(o, props, duration, {
			ease: easeFn,
			onComplete: function(_) {
				tweens.remove(tag);
				call('onTweenCompleted', [tag]);
			}
		}));
	}

	// ------------------------------------------------------------------ funciones comunes (Lua y HScript)

	/** Exit mod: menú original, sin scripts ni panel, hasta cambiar de mod / abrir Mods / tocar el aviso amarillo. */
	function exitModNow():Void
	{
		MainMenuData.forceOriginal = true;
		MusicBeatState.switchState(new states.MainMenuState());
	}

	function modName():String
		return Mods.currentModDirectory == null ? '' : Mods.currentModDirectory;

	function setBpmValue(bpm:Float):Void
		Conductor.bpm = bpm;

	/** controlPressed('ACCEPT'), 'BACK', 'UI_UP_P', 'UI_DOWN_P'... (propiedades de Controls). */
	function controlDown(name:String):Bool
		return Reflect.getProperty(Controls.instance, name.toUpperCase()) == true;

	/** Rectángulo de color sólido. Lo registra con `tag`; en Lua hay que añadirlo con addLuaSprite(tag). En HScript devuelve el sprite. */
	function makeGraphicObj(tag:String, width:Int, height:Int, color:String = '#FFFFFF'):FlxSprite
	{
		removeObj(tag, true);
		var s:FlxSprite = new FlxSprite().makeGraphic(width, height, MainMenuData.parseColor(color));
		s.scrollFactor.set();
		objects.set(tag, s);
		return s;
	}

	/** Música de menú que NO se reinicia si ya está sonando (misma pista) al pasar de un state a otro. name = ruta en music/ (sin extensión). */
	static var menuMusicName:String = null;
	static var menuMusicRef:FlxSound = null;

	function playMenuMusic(name:String, volume:Float = 1):Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music == menuMusicRef && menuMusicName == name && FlxG.sound.music.playing)
		{
			FlxG.sound.music.volume = volume;
			return;
		}
		FlxG.sound.playMusic(Paths.music(name), volume, true);
		menuMusicName = name;
		menuMusicRef = FlxG.sound.music;
	}

	/** El próximo switchState no usa el fade por defecto de Psych (para transiciones propias). */
	function skipTransition():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
	}

	/** Toque (Android, TouchInput de tu fork) o clic (PC). */
	function tapJustPressed():Bool
	{
		#if mobile
		return mobile.TouchInput.justTapped();
		#else
		return FlxG.mouse.justPressed;
		#end
	}

	function tapOverlaps(o:FlxSprite):Bool
	{
		#if mobile
		return mobile.TouchInput.justTapped() && mobile.TouchInput.tappedOn(o);
		#else
		return FlxG.mouse.justPressed && FlxG.mouse.overlaps(o);
		#end
	}

	function tapConsume():Void
	{
		#if mobile
		mobile.TouchInput.consumeTap();
		#end
	}

	/** Contorno para un FlxText: textOutline(txt, '#RRGGBB', grosor). */
	function textOutline(t:FlxText, color:String = '#000000', size:Float = 1):Void
		t.setBorderStyle(FlxTextBorderStyle.OUTLINE, MainMenuData.parseColor(color, FlxColor.BLACK), size);

	/** Ajusta un fondo a pantallas anchas (igual que el MainMenuState original). */
	function wideFit(o:FlxSprite):Void
		mobile.WideScreen.fit(o);

	/** Abre un substate propio (scripts/substates/<name>) o una clase FlxSubState por nombre. */
	function openSubStateByName(name:String):Bool
	{
		if (!MainMenuData.forceOriginal && MainMenuData.stateScriptExists('substates', name))
		{
			owner.openSubState(new states.ScriptedSubState(name));
			return true;
		}

		var cls:Class<Dynamic> = MainMenuData.resolveClassAny([name]);
		if (cls == null)
		{
			trace('SubState no encontrado: $name');
			return false;
		}
		owner.openSubState(cast Type.createInstance(cls, []));
		return true;
	}

	/** Cambia a un state propio (scripts/states/<name>) o a una clase por nombre. */
	function switchStateByName(name:String):Bool
	{
		if (MainMenuData.overridden(name)) // respeta "Exit mod" (forceOriginal)
		{
			MusicBeatState.switchState(new states.ScriptedState(name));
			return true;
		}

		var cls:Class<Dynamic> = MainMenuData.resolveClassAny([name]);
		if (cls == null)
		{
			trace('Clase no encontrada: $name');
			return false;
		}
		MusicBeatState.switchState(cast Type.createInstance(cls, []));
		return true;
	}

	public function destroy():Void
	{
		call('onDestroy');

		for (t in tweens) t.cancel();
		for (t in timers) t.cancel();
		tweens.clear();
		timers.clear();

		for (tag in [for (k in objects.keys()) k]) removeObj(tag, true);

		#if LUA_ALLOWED
		for (s in luas)
			if (s.lua != null) { Lua.close(s.lua); s.lua = null; }
		luas = [];
		for (n in registered) Lua_helper.callbacks.remove(n);
		registered = [];
		#end

		#if HSCRIPT_ALLOWED
		for (h in hscripts) h.destroy();
		hscripts = [];
		#end
	}
}
