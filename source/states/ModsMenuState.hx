package states;

import backend.WeekData;
import backend.Mods;

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import flash.geom.Rectangle;
import haxe.Json;

import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import flixel.math.FlxMath;
import objects.AttachedSprite;
import options.ModSettingsSubState;

import openfl.display.BitmapData;
import lime.utils.Assets;

/**
 * Mods menu con el look del mod menu de V-Slice y el sistema de mods de Psych
 * (modsList.txt, pack.json, settings.json, reorden, reload, etc.).
 *
 * Izquierda = mods desactivados, derecha = mods activados.
 * La barra de opciones de Psych (reload / enable all / mover / settings / on-off)
 * va debajo de las cajas.
 *
 * Todo lo necesario va en este archivo (incluye ModItem, MenuButton, Sparks, Ambience y botón Done).
 */
class ModsMenuState extends MusicBeatState
{
	/** Fuente de todos los textos. Cámbiala por la de V-Slice si la tienes (ej. 'FunkinLingLong.otf'). */
	public static var FONT:String = 'vcr.ttf';

	/** Prefijos de animación de BF/GF en tus XML: nombre interno => prefijo del XML. */
	public static var CHAR_PREFIX:Map<String, String> = [
		'idle' => 'idle',
		'electrocuted' => 'electrocuted',
		'crispy' => 'crispy',
		'crispy-loop' => 'crispy loop'
	];

	static inline final ROW_TOP:Int = 60; // espacio entre el borde de la caja y el primer item
	static inline final ROW_SPACING:Int = 102;

	// Fondo y decoración
	var menuBG:FlxSprite;
	var topText:FlxSprite;
	var dragText:FlxText;
	var boxes:Array<FlxSprite> = [];
	var listTitles:Array<FlxText> = [];
	var backArrow:FlxSprite = null;
	var restartText:FlxText;

	// Escena de personajes
	var carBattery:FlxSprite;
	var gfWire:FlxSprite;
	var bf:FlxSprite;
	var gf:FlxSprite;
	var bgWires:FlxSprite;
	var fgWires:FlxSprite;
	var smokeBF:FlxSprite;
	var smokeGF:FlxSprite;
	var smokeCloud:FlxSprite;
	var sparks:ModMenuSparks;
	var ambience:ModMenuAmbience;
	var shocking:Bool = false;

	// Botones
	var buttonDone:ModMenuButton;
	var buttonReload:MenuButton;
	var buttonEnableAll:MenuButton;
	var buttonDisableAll:MenuButton;
	var buttonTop:MenuButton;
	var buttonUp:MenuButton;
	var buttonDown:MenuButton;
	var settingsButton:MenuButton;
	var buttonToggle:MenuButton;

	// Datos de mods (sistema de Psych)
	var modsList:ModsList = null;
	var items:Map<String, ModItem> = [];
	var itemsGroup:FlxTypedGroup<ModItem>;
	var lists:Array<Array<ModItem>> = [[], []]; // 0 = desactivados (izq), 1 = activados (der)
	var sel:Array<Int> = [0, 0];
	var scroll:Array<Int> = [0, 0];
	var curList:Int = 0;
	var visibleRows:Int = 4;

	// Navegación
	var inBar:Bool = false;
	var curButton:Int = 0; // 0 reload, 1 enable/disable all, 2 top, 3 up, 4 down, 5 settings, 6 on/off
	var holdTime:Float = 0;
	var waitingToRestart:Bool = false;
	var exiting:Bool = false;
	var startMod:String = null;
	var _lastControllerMode:Bool = false;

	// Ratón / touch
	var pressedItem:ModItem = null;
	var dragItem:ModItem = null;
	var mouseOffsets:FlxPoint = new FlxPoint();

	var noModsSine:Float = 0;
	var noModsTxt:FlxText;
	var nextAttempt:Float = 1;

	public function new(startMod:String = null)
	{
		this.startMod = startMod;
		super();
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		persistentUpdate = false;

		modsList = Mods.parseList();
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		var ox:Float = mobile.WideScreen.offset;

		// ---- Fondo / título -------------------------------------------------
		menuBG = new FlxSprite().loadGraphic(Paths.image('ui/mods/bg'));
		menuBG.scale.set(0.66, 0.67);
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = ClientPrefs.data.antialiasing;
		add(menuBG);

		topText = new FlxSprite().loadGraphic(Paths.image('ui/mods/top-text'));
		topText.scale.set(0.66, 0.67);
		topText.updateHitbox();
		topText.screenCenter(X);
		topText.y = FlxG.height * 0.035;
		topText.antialiasing = ClientPrefs.data.antialiasing;
		add(topText);

		// ---- Cajas ----------------------------------------------------------
		var boxY:Float = FlxG.height * 0.19;
		var distanceBetweenBoxes:Float = 35;
		for (i in 0...2)
		{
			var box = new FlxSprite().loadGraphic(Paths.image('ui/mods/box'));
			box.scale.set(0.64, 0.67);
			box.updateHitbox();
			// Que nunca tape la barra de opciones de abajo
			var maxH:Float = FlxG.height - 92 - boxY;
			if (box.height > maxH)
			{
				box.setGraphicSize(Std.int(box.width), Std.int(maxH));
				box.updateHitbox();
			}
			box.antialiasing = ClientPrefs.data.antialiasing;
			box.y = boxY;
			box.x = (i == 0) ? (FlxG.width * 0.047 + ox) : (boxes[0].x + boxes[0].width + distanceBetweenBoxes);
			boxes.push(box);
			add(box);
		}
		visibleRows = Std.int(Math.max(1, Math.floor((boxes[0].height - 75) / ROW_SPACING)));

		var dragWidth:Float = boxes[1].x + boxes[1].width - boxes[0].x;
		dragText = new FlxText(boxes[0].x, FlxG.height * 0.13, dragWidth, Language.getPhrase('mods_drag_hint', 'Hold a mod and drop it on the other window'), 24);
		#if mobile
		dragText.text = Language.getPhrase('mods_drag_hint_touch', 'Tap and hold on a mod to drag it');
		#end
		dragText.setFormat(Paths.font(FONT), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		dragText.borderSize = 1.5;
		add(dragText);

		var titles:Array<String> = [Language.getPhrase('mods_disabled', 'DISABLED'), Language.getPhrase('mods_enabled', 'ENABLED')];
		for (i in 0...2)
		{
			var t = new FlxText(boxes[i].x, boxes[i].y + 14, boxes[i].width, titles[i], 32);
			t.setFormat(Paths.font(FONT), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.borderSize = 2;
			listTitles.push(t);
			add(t);
		}

		// ---- Escena: cables de fondo ---------------------------------------
		carBattery = makeSparrow(boxes[1].x + 475.6, FlxG.height * 0.11, 'ui/mods/carbattery');
		carBattery.animation.addByPrefix('idle', 'idle', 24);
		playIf(carBattery, 'idle');
		if (carBattery.animation.curAnim != null) carBattery.animation.pause();
		carBattery.scale.set(0.75, 0.75);
		carBattery.updateHitbox();

		bgWires = new FlxSprite(carBattery.x + 75, carBattery.y + 170);
		if (Paths.fileExists('images/ui/mods/bgwires.png', IMAGE)) bgWires.loadGraphic(Paths.image('ui/mods/bgwires'));
		else bgWires.visible = false;
		bgWires.scale.set(0.7, 0.7);
		bgWires.updateHitbox();
		bgWires.antialiasing = ClientPrefs.data.antialiasing;
		add(bgWires);

		// ---- Items (después de las cajas, antes de los personajes) ----------
		itemsGroup = new FlxTypedGroup<ModItem>();
		add(itemsGroup);

		for (mod in modsList.all)
		{
			var item:ModItem = new ModItem(mod);
			items.set(mod, item);
			itemsGroup.add(item);
		}
		refreshLists();

		if (startMod != null && items.exists(startMod))
		{
			var it = items.get(startMod);
			curList = listOf(it);
			sel[curList] = lists[curList].indexOf(it);
		}
		else if (lists[0].length < 1 && lists[1].length > 0) curList = 1;

		// ---- Escena: batería y personajes ----------------------------------
		add(carBattery);

		gfWire = makeSparrow(carBattery.x - 117, carBattery.y - 18, 'ui/mods/gfwire');
		gfWire.animation.addByPrefix('idle', 'idle0', 24, false);
		gfWire.animation.addByPrefix('shock', 'shock', 24, false);
		playIf(gfWire, 'idle');
		gfWire.scale.set(0.7, 0.7);
		gfWire.updateHitbox();
		add(gfWire);

		gf = makeCharacter(0, 0, 'gf');
		bf = makeCharacter(carBattery.x - 119, carBattery.y + 50, 'bf');
		gf.setPosition(bf.x - 166, bf.y);
		add(gf);
		add(bf);

		fgWires = makeSparrow(bf.x - 144, bf.y - 90, 'ui/mods/foreground-wires');
		fgWires.animation.addByPrefix('idle', 'idle', 24, true);
		fgWires.animation.addByPrefix('shock', 'shock', 24, true);
		fgWires.animation.addByPrefix('end', 'end', 24, false);
		playIf(fgWires, 'idle');
		fgWires.scale.set(0.7, 0.7);
		fgWires.updateHitbox();
		add(fgWires);

		smokeBF = makeSparrow(bf.x + 70, bf.y - 180, 'ui/mods/smoke');
		smokeBF.animation.addByPrefix('idle', 'retry_smoke', 24, true);
		smokeGF = makeSparrow(gf.x + 70, gf.y - 180, 'ui/mods/smoke');
		smokeGF.animation.addByPrefix('idle', 'retry_smoke', 24, true);
		for (s in [smokeBF, smokeGF])
		{
			playIf(s, 'idle');
			s.scale.set(0.5, 0.5);
			s.updateHitbox();
			s.alpha = 0.67; // el valor real del FLA
			s.visible = false;
			add(s);
		}
		smokeBF.animation.curAnim != null ? smokeBF.animation.curAnim.curFrame = 13 : null;

		smokeCloud = makeSparrow(carBattery.x - 415, -450, 'ui/mods/smoke-cloud');
		smokeCloud.animation.addByPrefix('cloud', '', 24, false);
		smokeCloud.scale.set(0.75, 0.75);
		smokeCloud.updateHitbox();
		smokeCloud.visible = false;
		add(smokeCloud);

		sparks = new ModMenuSparks(0, 0);
		add(sparks);

		// ---- Flecha de volver y botón Done ---------------------------------
		buildBackArrow();

		buttonDone = new ModMenuButton(carBattery.x - 100, FlxG.height * 0.89, 'done');
		buttonDone.scale.set(0.65, 0.65);
		buttonDone.updateHitbox();
		buttonDone.antialiasing = ClientPrefs.data.antialiasing;
		add(buttonDone);

		// ---- Barra de opciones (sistema de botones de Psych) ---------------
		var barH:Int = 56;
		var barY:Float = FlxG.height - barH - 10;
		var barX:Float = boxes[0].x;

		restartText = new FlxText(boxes[0].x, FlxG.height - barH - 10 - 20, dragWidth, Language.getPhrase('mod_restart', '* Moving or Toggling On/Off this Mod will restart the game.'), 14);
		restartText.setFormat(Paths.font(FONT), 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		restartText.visible = false;
		add(restartText);

		buttonReload = new MenuButton(barX, barY, 120, barH, Language.getPhrase('reload_button', 'RELOAD'), null, reload);
		add(buttonReload);

		var allX:Float = barX + 128;
		buttonEnableAll = new MenuButton(allX, barY, 170, barH, Language.getPhrase('enable_all_button', 'ENABLE ALL'), null, function() {
			buttonEnableAll.ignoreCheck = false;
			for (m in modsList.disabled.copy())
			{
				modsList.disabled.remove(m);
				modsList.enabled.push(m);
			}
			shock(true);
			afterBulkChange();
		});
		buttonEnableAll.baseColor = FlxColor.GREEN;
		buttonEnableAll.setButtonVisibility(false);
		add(buttonEnableAll);

		buttonDisableAll = new MenuButton(allX, barY, 170, barH, Language.getPhrase('disable_all_button', 'DISABLE ALL'), null, function() {
			buttonDisableAll.ignoreCheck = false;
			for (m in modsList.enabled.copy())
			{
				modsList.enabled.remove(m);
				modsList.disabled.push(m);
			}
			afterBulkChange();
		});
		buttonDisableAll.baseColor = 0xFFFF6666;
		buttonDisableAll.setButtonVisibility(false);
		add(buttonDisableAll);

		var iconX:Float = allX + 170 + 16;
		var sheet:FlxGraphic = Paths.image('modsMenuButtons');

		buttonTop = makeIconButton(iconX, barY, barH, sheet, 0, function() moveSelected(true, 0));
		buttonUp = makeIconButton(iconX + (barH + 8), barY, barH, sheet, 1, function() moveSelected(false, -1));
		buttonDown = makeIconButton(iconX + (barH + 8) * 2, barY, barH, sheet, 2, function() moveSelected(false, 1));
		settingsButton = makeIconButton(iconX + (barH + 8) * 3, barY, barH, sheet, 3, openSettings);
		buttonToggle = makeIconButton(iconX + (barH + 8) * 4, barY, barH, sheet, 4, function() {
			var it = selectedItem();
			if (it != null) toggleItem(it);
		});

		// ---- Sin mods instalados -------------------------------------------
		if (modsList.all.length < 1)
		{
			var myX:Float = boxes[0].x;
			noModsTxt = new FlxText(myX, 0, dragWidth, Language.getPhrase('no_mods_installed', 'NO MODS INSTALLED\nPRESS BACK TO EXIT OR INSTALL A MOD'), 32);
			noModsTxt.setFormat(Paths.font(FONT), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			noModsTxt.borderSize = 2;
			add(noModsTxt);
			noModsTxt.screenCenter(Y);
			FlxG.autoPause = false;
		}

		ambience = new ModMenuAmbience('ui/mods/mod-menu-ambience/mod-menu-ambience', []);
		ambience.start();

		_lastControllerMode = controls.controllerMode;

		layoutLists(true);
		updateSelectionVisuals();
		updateBarState();

		#if mobile
		add(mobile.MobileButton.back(null, true));
		#end
		super.create();
	}

	// =====================================================================
	//  Construcción
	// =====================================================================

	function makeSparrow(x:Float, y:Float, key:String):FlxSprite
	{
		var s = new FlxSprite(x, y);
		if (Paths.fileExists('images/$key.xml', TEXT))
		{
			s.frames = Paths.getSparrowAtlas(key);
			s.antialiasing = ClientPrefs.data.antialiasing;
		}
		else
		{
			s.makeGraphic(1, 1, FlxColor.TRANSPARENT);
			s.visible = false;
		}
		return s;
	}

	function makeCharacter(x:Float, y:Float, id:String):FlxSprite
	{
		var c = makeSparrow(x, y, 'ui/mods/characters/$id');
		for (name => prefix in CHAR_PREFIX)
			c.animation.addByPrefix(name, prefix, 24, (name == 'idle' || name == 'crispy-loop'));
		playIf(c, 'idle');
		c.scale.set(0.7, 0.7);
		c.updateHitbox();
		return c;
	}

	function playIf(s:FlxSprite, name:String, force:Bool = true)
	{
		if (s != null && s.animation.getByName(name) != null) s.animation.play(name, force);
	}

	function makeIconButton(x:Float, y:Float, size:Int, sheet:FlxGraphic, frame:Int, onClick:Void->Void):MenuButton
	{
		var b = new MenuButton(x, y, size, size, null, sheet, onClick, 54, 54);
		b.icon.animation.add('icon', [frame]);
		b.icon.animation.play('icon', true);
		add(b);
		return b;
	}

	function buildBackArrow()
	{
		backArrow = new FlxSprite();
		if (Paths.fileExists('images/ui/mods/back-arrow.xml', TEXT))
		{
			backArrow.frames = Paths.getSparrowAtlas('ui/mods/back-arrow');
			backArrow.animation.addByPrefix('idle', 'default', 24, true);
			backArrow.animation.addByPrefix('hover', 'highlighted', 24, true);
			backArrow.animation.addByPrefix('confirm', 'confirm', 24, false);
			playIf(backArrow, 'idle');
		}
		else if (Paths.fileExists('images/ui/mods/back-arrow.png', IMAGE))
			backArrow.loadGraphic(Paths.image('ui/mods/back-arrow'));
		else
		{
			backArrow.destroy();
			backArrow = null;
			return;
		}
		backArrow.scale.set(0.7, 0.7);
		backArrow.updateHitbox();
		backArrow.antialiasing = ClientPrefs.data.antialiasing;
		backArrow.x = 10 + mobile.WideScreen.offset;
		backArrow.y = topText.y + (topText.height / 2) - (backArrow.height / 2) + 3;
		add(backArrow);
	}

	// =====================================================================
	//  Listas
	// =====================================================================

	/** 0 = desactivado (izquierda), 1 = activado (derecha). */
	function listOf(it:ModItem):Int
	{
		return modsList.disabled.contains(it.folder) ? 0 : 1;
	}

	function selectedItem():ModItem
	{
		var l = lists[curList];
		if (l.length < 1) return null;
		return l[Std.int(FlxMath.bound(sel[curList], 0, l.length - 1))];
	}

	/** Reconstruye las dos listas respetando el orden de modsList.all. */
	function refreshLists()
	{
		lists = [[], []];
		for (m in modsList.all)
		{
			var it = items.get(m);
			if (it == null) continue;
			lists[modsList.disabled.contains(m) ? 0 : 1].push(it);
		}
	}

	function itemX(li:Int):Float
	{
		return boxes[li].x + (boxes[li].width - ModItem.WIDTH) / 2;
	}

	function layoutLists(instant:Bool)
	{
		for (li in 0...2)
		{
			var l = lists[li];
			sel[li] = Std.int(FlxMath.bound(sel[li], 0, Math.max(0, l.length - 1)));
			scroll[li] = Std.int(FlxMath.bound(scroll[li], 0, Math.max(0, l.length - visibleRows)));
			if (sel[li] < scroll[li]) scroll[li] = sel[li];
			else if (sel[li] >= scroll[li] + visibleRows) scroll[li] = sel[li] - visibleRows + 1;

			for (i => it in l)
			{
				it.targetX = itemX(li);
				it.targetY = boxes[li].y + ROW_TOP + (i - scroll[li]) * ROW_SPACING;
				it.visible = (i >= scroll[li] && i < scroll[li] + visibleRows) || it == dragItem;
				if (instant) it.setPosition(it.targetX, it.targetY);
			}
		}
	}

	function updateSelectionVisuals()
	{
		for (li in 0...2)
			for (i => it in lists[li])
			{
				var a:Float = 0;
				if (i == sel[li]) a = (li == curList) ? (inBar ? 0.15 : 0.3) : 0.1;
				it.setHighlight(a);
			}
	}

	function updateBarState()
	{
		var hasAny:Bool = modsList.all.length > 0;
		var anyDisabled:Bool = modsList.disabled.length > 0;
		buttonEnableAll.visible = buttonEnableAll.enabled = hasAny && anyDisabled;
		buttonDisableAll.visible = buttonDisableAll.enabled = hasAny && !anyDisabled;

		var it = selectedItem();
		var l = lists[curList];
		var canMove:Bool = (it != null && l.length > 1);
		buttonTop.enabled = canMove && sel[curList] > 0;
		buttonUp.enabled = canMove && sel[curList] > 0;
		buttonDown.enabled = canMove && sel[curList] < l.length - 1;
		settingsButton.enabled = (it != null && it.settings != null && it.settings.length > 0);
		buttonToggle.enabled = (it != null);
		buttonToggle.baseColor = (it != null && listOf(it) == 1) ? FlxColor.GREEN : 0xFFFF6666;
		buttonToggle.setButtonVisibility(buttonToggle.onFocus);

		restartText.visible = (it != null && it.mustRestart);
	}

	function afterBulkChange()
	{
		var it = selectedItem();
		refreshLists();
		if (it != null)
		{
			curList = listOf(it);
			sel[curList] = lists[curList].indexOf(it);
		}
		layoutLists(false);
		updateSelectionVisuals();
		updateBarState();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function changeSelection(add:Int, jumpToBar:Bool = true)
	{
		var l = lists[curList];
		if (l.length < 1) return;

		var next:Int = sel[curList] + add;
		if (next >= l.length && jumpToBar && Math.abs(add) == 1)
		{
			focusBar(true);
			return;
		}
		sel[curList] = Std.int(FlxMath.bound(next, 0, l.length - 1));
		if (sel[curList] == next - add && add != 0) return; // ya estaba en el borde

		layoutLists(false);
		updateSelectionVisuals();
		updateBarState();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function switchList(dir:Int)
	{
		var target:Int = curList + dir;
		if (target < 0 || target > 1 || lists[target].length < 1) return;
		curList = target;
		layoutLists(false);
		updateSelectionVisuals();
		updateBarState();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function selectItem(it:ModItem)
	{
		var li = listOf(it);
		curList = li;
		sel[li] = lists[li].indexOf(it);
		layoutLists(false);
		updateSelectionVisuals();
		updateBarState();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	// =====================================================================
	//  Acciones sobre mods
	// =====================================================================

	function toggleItem(it:ModItem)
	{
		var m:String = it.folder;
		if (modsList.disabled.contains(m))
		{
			modsList.disabled.remove(m);
			modsList.enabled.push(m);
			shock(false);
		}
		else
		{
			modsList.enabled.remove(m);
			modsList.disabled.push(m);
		}
		if (it.mustRestart) waitingToRestart = true;

		refreshLists();
		curList = listOf(it);
		sel[curList] = lists[curList].indexOf(it);
		layoutLists(false);
		updateSelectionVisuals();
		updateBarState();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	/** Mueve el mod seleccionado dentro de su lista (top = al principio, si no delta = +-1). */
	function moveSelected(top:Bool, delta:Int)
	{
		var l = lists[curList];
		var i = sel[curList];
		var target:Int = top ? 0 : i + delta;
		if (target < 0 || target >= l.length || target == i) return;
		reorder(l[i], l[target]);
	}

	/** Pone `it` en la posición de `target` dentro de modsList.all (misma lista). */
	function reorder(it:ModItem, target:ModItem)
	{
		if (it == target) return;
		var b:Int = modsList.all.indexOf(target.folder);
		modsList.all.remove(it.folder);
		modsList.all.insert(b, it.folder);
		if (it.mustRestart || target.mustRestart) waitingToRestart = true;

		refreshLists();
		curList = listOf(it);
		sel[curList] = lists[curList].indexOf(it);
		layoutLists(false);
		updateSelectionVisuals();
		updateBarState();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function openSettings()
	{
		var it = selectedItem();
		if (it != null && it.settings != null && it.settings.length > 0)
			openSubState(new ModSettingsSubState(it.settings, it.folder, it.name));
	}

	// =====================================================================
	//  Efectos de la escena
	// =====================================================================

	function shock(long:Bool)
	{
		if (shocking) return;
		shocking = true;

		sparks.startElectrocution();
		playIf(bf, 'electrocuted');
		playIf(gf, 'electrocuted');
		playIf(gfWire, 'shock');
		playIf(fgWires, 'shock');

		new FlxTimer().start(long ? 2.0 : 0.8, function(_) {
			sparks.endElectrocution();
			playIf(fgWires, 'end');
			if (long) crispy();
			else
			{
				playIf(bf, 'idle');
				playIf(gf, 'idle');
				playIf(gfWire, 'idle');
				shocking = false;
			}
		});
	}

	function crispy()
	{
		playIf(bf, 'crispy');
		playIf(gf, 'crispy');
		smokeBF.visible = smokeGF.visible = true;
		playSnd('ui/mods/sounds/crispy', 1);

		if (smokeCloud.animation.getByName('cloud') != null)
		{
			smokeCloud.visible = true;
			smokeCloud.animation.play('cloud', true);
			smokeCloud.animation.finishCallback = function(_) smokeCloud.visible = false;
			playSnd('ui/mods/sounds/smoke-cloud', 1);
		}

		new FlxTimer().start(4, function(_) {
			smokeBF.visible = smokeGF.visible = false;
			playIf(bf, 'idle');
			playIf(gf, 'idle');
			playIf(gfWire, 'idle');
			playIf(fgWires, 'idle');
			shocking = false;
		});
	}

	public static function soundExists(key:String):Bool
	{
		return Paths.fileExists('sounds/$key.ogg', SOUND);
	}

	public static function playSnd(key:String, vol:Float = 1):FlxSound
	{
		if (!soundExists(key)) return null;
		return FlxG.sound.play(Paths.sound(key), vol);
	}

	// =====================================================================
	//  Foco de la barra
	// =====================================================================

	function barButton(i:Int):MenuButton
	{
		switch (i)
		{
			case 0: return buttonReload;
			case 1: return buttonEnableAll.enabled ? buttonEnableAll : buttonDisableAll;
			case 2: return buttonTop;
			case 3: return buttonUp;
			case 4: return buttonDown;
			case 5: return settingsButton;
			default: return buttonToggle;
		}
	}

	function clearBarFocus()
	{
		for (i in 0...7)
		{
			var b = barButton(i);
			b.ignoreCheck = b.onFocus = false;
		}
		buttonEnableAll.onFocus = buttonDisableAll.onFocus = false;
	}

	function focusBar(on:Bool)
	{
		clearBarFocus();
		inBar = on;
		if (on)
		{
			curButton = Std.int(FlxMath.bound(curButton, 0, 6));
			var b = barButton(curButton);
			b.ignoreCheck = b.onFocus = true;
		}
		updateSelectionVisuals();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function changeBarButton(add:Int)
	{
		var b = barButton(curButton);
		b.ignoreCheck = b.onFocus = false;
		curButton = Std.int(FlxMath.bound(curButton + add, 0, 6));
		b = barButton(curButton);
		b.ignoreCheck = b.onFocus = true;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	// =====================================================================
	//  Update
	// =====================================================================

	#if mobile
	var dragAccum:Float = 0;
	var touchHoldTime:Float = 0;

	override function destroy()
	{
		mobile.TouchInput.blockGestures = false;
		if (ambience != null) ambience.destroy();
		super.destroy();
	}
	#else
	override function destroy()
	{
		if (ambience != null) ambience.destroy();
		super.destroy();
	}
	#end

	function itemAtMouse():ModItem
	{
		for (li in 0...2)
			for (it in lists[li])
				if (it.visible && FlxG.mouse.overlaps(it)) return it;
		return null;
	}

	override function update(elapsed:Float)
	{
		#if mobile
		mobile.TouchInput.blockGestures = true;
		if (FlxG.mouse.justPressed) touchHoldTime = 0;
		else if (FlxG.mouse.pressed) touchHoldTime += elapsed;
		#end

		if (exiting)
		{
			super.update(elapsed);
			return;
		}

		if (controls.BACK)
		{
			if (inBar) focusBar(false);
			else
			{
				exitMenu();
				return;
			}
		}

		if (Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10)
		{
			controls.controllerMode = false;
			if (!FlxG.mouse.visible) FlxG.mouse.visible = true;
		}

		if (controls.controllerMode != _lastControllerMode)
		{
			if (controls.controllerMode) FlxG.mouse.visible = false;
			_lastControllerMode = controls.controllerMode;
		}

		updateDoneAndBack();

		if (controls.UI_DOWN_R || controls.UI_UP_R) holdTime = 0;

		if (modsList.all.length > 0)
		{
			if (controls.controllerMode && dragItem != null) cancelDrag();

			#if mobile
			if (!inBar && dragItem == null && mobile.TouchInput.isDragging())
			{
				dragAccum += mobile.TouchInput.dragDeltaY();
				while (dragAccum >= 80)
				{
					dragAccum -= 80;
					changeSelection(-1, false);
				}
				while (dragAccum <= -80)
				{
					dragAccum += 80;
					changeSelection(1, false);
				}
			}
			else dragAccum = 0;
			#end

			updateMouse(elapsed);

			if (!inBar)
			{
				var shiftMult:Int = (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) || FlxG.gamepads.anyPressed(RIGHT_SHOULDER)) ? 4 : 1;
				if (controls.UI_DOWN_P) changeSelection(shiftMult);
				else if (controls.UI_UP_P) changeSelection(-shiftMult);
				else if (FlxG.mouse.wheel != 0) changeSelection(-FlxG.mouse.wheel * shiftMult, false);
				else if (controls.UI_UP || controls.UI_DOWN)
				{
					var lastHoldTime:Float = holdTime;
					holdTime += elapsed;
					if (holdTime > 0.5 && Math.floor(lastHoldTime * 8) != Math.floor(holdTime * 8))
						changeSelection(shiftMult * (controls.UI_UP ? -1 : 1));
				}

				if (controls.UI_LEFT_P) switchList(-1);
				else if (controls.UI_RIGHT_P) switchList(1);
				else if (controls.ACCEPT)
				{
					var it = selectedItem();
					if (it != null) toggleItem(it);
				}
			}
			else
			{
				if (controls.UI_UP_P) focusBar(false);
				else if (controls.UI_LEFT_P) changeBarButton(-1);
				else if (controls.UI_RIGHT_P) changeBarButton(1);
				else if (controls.ACCEPT)
				{
					var b = barButton(curButton);
					if (b.enabled && b.onClick != null) b.onClick();
				}
			}
		}
		else
		{
			noModsSine += 180 * elapsed;
			noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);

			// Sigue refrescando la lista cada segundo hasta que agregues un mod
			nextAttempt -= elapsed;
			if (nextAttempt < 0)
			{
				nextAttempt = 1;
				@:privateAccess
				Mods.updateModList();
				modsList = Mods.parseList();
				if (modsList.all.length > 0)
				{
					trace('mod(s) found! reloading');
					reload();
				}
			}
		}
		super.update(elapsed);
	}

	function updateMouse(elapsed:Float)
	{
		if (FlxG.mouse.justPressed)
		{
			var it = itemAtMouse();
			pressedItem = it;
			if (it != null)
			{
				if (inBar) focusBar(false);
				mouseOffsets.set(FlxG.mouse.x - it.x, FlxG.mouse.y - it.y);
				selectItem(it);
			}
		}
		else if (FlxG.mouse.pressed && pressedItem != null)
		{
			if (dragItem == null && FlxG.mouse.justMoved && FlxG.mouse.overlaps(pressedItem)
				#if mobile && touchHoldTime > 0.4 && !mobile.TouchInput.isDragging() #end)
			{
				dragItem = pressedItem;
				dragItem.dragged = true;
			}
			if (dragItem != null)
			{
				dragItem.x = FlxG.mouse.x - mouseOffsets.x;
				dragItem.y = FlxG.mouse.y - mouseOffsets.y;
			}
		}
		else if (FlxG.mouse.justReleased)
		{
			if (dragItem != null) dropItem(dragItem);
			pressedItem = null;
		}
	}

	function dropItem(it:ModItem)
	{
		it.dragged = false;
		dragItem = null;
		var from:Int = listOf(it);
		var other:Int = 1 - from;

		if (FlxG.mouse.overlaps(boxes[other])) toggleItem(it);
		else if (FlxG.mouse.overlaps(boxes[from]))
		{
			var l = lists[from];
			var row:Int = Math.floor((FlxG.mouse.y - (boxes[from].y + ROW_TOP)) / ROW_SPACING) + scroll[from];
			row = Std.int(FlxMath.bound(row, 0, l.length - 1));
			if (l[row] != it) reorder(it, l[row]);
			else layoutLists(false);
		}
		else layoutLists(false);
	}

	function cancelDrag()
	{
		if (dragItem != null) dragItem.dragged = false;
		dragItem = null;
		layoutLists(false);
	}

	function updateDoneAndBack()
	{
		var overDone:Bool = !controls.controllerMode && FlxG.mouse.visible && FlxG.mouse.overlaps(buttonDone);
		buttonDone.selected = overDone;
		var s:Float = FlxMath.lerp(buttonDone.scale.x, overDone ? 0.72 : 0.65, 0.3);
		buttonDone.scale.set(s, s);
		if (overDone && FlxG.mouse.justPressed)
		{
			exitMenu();
			return;
		}

		if (backArrow != null)
		{
			var overBack:Bool = !controls.controllerMode && FlxG.mouse.visible && FlxG.mouse.overlaps(backArrow);
			playIf(backArrow, overBack ? 'hover' : 'idle', false);
			if (overBack && FlxG.mouse.justPressed)
			{
				playIf(backArrow, 'confirm');
				exitMenu();
			}
		}
	}

	// =====================================================================
	//  Salir / recargar / guardar (igual que en Psych)
	// =====================================================================

	function exitMenu()
	{
		if (exiting) return;
		exiting = true;

		saveTxt();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		if (ambience != null) ambience.stop(0.3);

		if (waitingToRestart)
		{
			TitleState.initialized = false;
			TitleState.closedState = false;
			FlxG.sound.music.fadeOut(0.3);
			if (FreeplayState.vocals != null)
			{
				FreeplayState.vocals.fadeOut(0.3);
				FreeplayState.vocals = null;
			}
			FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
		}
		else MusicBeatState.switchState(new MainMenuState());

		persistentUpdate = false;
		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxG.mouse.visible = false;
	}

	function reload()
	{
		saveTxt();
		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		var it:ModItem = selectedItem();
		MusicBeatState.switchState(new ModsMenuState(it != null ? it.folder : null));
	}

	function saveTxt()
	{
		var fileStr:String = '';
		for (mod in modsList.all)
		{
			if (mod.trim().length < 1) continue;

			if (fileStr.length > 0) fileStr += '\n';

			var on = '1';
			if (modsList.disabled.contains(mod)) on = '0';
			fileStr += '$mod|$on';
		}

		var path:String = 'modsList.txt';
		File.saveContent(path, fileStr);
		Mods.parseList();
		Mods.loadTopMod();
	}
}

/**
 * Item de la lista, con el estilo de V-Slice: icono 96x96, título y descripción.
 * Los datos salen de pack.json / settings.json como en Psych.
 */
class ModItem extends FlxSpriteGroup
{
	public static inline final WIDTH:Int = 326;
	public static inline final ICON_SIZE:Int = 96;
	public static inline final TEXT_WIDTH:Int = 216;

	public var selectBg:FlxSprite;
	public var icon:FlxSprite;
	public var text:FlxText;
	public var descText:FlxText;
	public var totalFrames:Int = 0;

	// posición objetivo (el item se desliza hacia ella)
	public var targetX:Float = 0;
	public var targetY:Float = 0;
	public var dragged:Bool = false;

	// options
	public var name:String = 'Unknown Mod';
	public var desc:String = 'No description provided.';
	public var iconFps:Int = 10;
	public var bgColor:FlxColor = 0xFF665AFF;
	public var pack:Dynamic = null;
	public var folder:String = 'unknownMod';
	public var mustRestart:Bool = false;
	public var settings:Array<Dynamic> = null;

	public function new(folder:String)
	{
		super();

		this.folder = folder;
		pack = Mods.getPack(folder);

		var path:String = Paths.mods('$folder/data/settings.json');
		if (FileSystem.exists(path))
		{
			try
			{
				settings = tjson.TJSON.parse(File.getContent(path));
			}
			catch (e:Dynamic)
			{
				var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
				var errorMsg = 'An error occurred: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				trace('$errorTitle - $errorMsg');
			}
		}

		selectBg = new FlxSprite().makeGraphic(WIDTH, ICON_SIZE, FlxColor.WHITE);
		selectBg.alpha = 0;
		add(selectBg);

		icon = new FlxSprite(0, 0);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		add(icon);

		text = new FlxText(ICON_SIZE + 8, 6, TEXT_WIDTH, "", 24);
		text.setFormat(Paths.font(ModsMenuState.FONT), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 1.5;
		text.wordWrap = false;
		add(text);

		descText = new FlxText(ICON_SIZE + 8, 42, TEXT_WIDTH, "", 16);
		descText.setFormat(Paths.font(ModsMenuState.FONT), 16, FlxColor.WHITE, LEFT);
		descText.alpha = 0.7;
		add(descText);

		var isPixel = false;
		var file:String = Paths.mods('$folder/pack.png');
		if (!FileSystem.exists(file))
		{
			file = Paths.mods('$folder/pack-pixel.png');
			isPixel = true;
		}

		var bmp:BitmapData = null;
		if (FileSystem.exists(file)) bmp = BitmapData.fromFile(file);
		else isPixel = false;

		if (FileSystem.exists(file))
		{
			icon.loadGraphic(Paths.cacheBitmap(file, bmp), true, 150, 150);
			if (isPixel) icon.antialiasing = false;
		}
		else icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		var s:Float = ICON_SIZE / 150;
		icon.scale.set(s, s);
		icon.updateHitbox();
		icon.setPosition(x, y);

		this.name = folder;
		if (pack != null)
		{
			if (pack.name != null) this.name = pack.name;
			if (pack.description != null) this.desc = pack.description;
			if (pack.iconFramerate != null) this.iconFps = pack.iconFramerate;
			if (pack.color != null)
			{
				this.bgColor = FlxColor.fromRGB(pack.color[0] != null ? pack.color[0] : 170,
											  pack.color[1] != null ? pack.color[1] : 0,
											  pack.color[2] != null ? pack.color[2] : 255);
			}
			this.mustRestart = (pack.restart == true);
		}
		text.text = this.name;
		descText.text = this.desc;
		descText.fieldHeight = 54; // recorta descripciones largas, como en V-Slice

		if (bmp != null)
		{
			totalFrames = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
			icon.animation.add("icon", [for (i in 0...totalFrames) i], iconFps);
			icon.animation.play("icon");
		}
	}

	public function setHighlight(a:Float)
	{
		selectBg.alpha = a;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!dragged && visible)
		{
			var t:Float = Math.min(1, elapsed * 16);
			x = x + (targetX - x) * t;
			y = y + (targetY - y) * t;
		}
	}
}

/**
 * Botón de la barra de opciones (versión de Psych con estilo V-Slice).
 * Texto con FlxText en vez de Alphabet.
 */
class MenuButton extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var label:FlxText;
	public var icon:FlxSprite;
	public var onClick:Void->Void = null;
	public var enabled(default, set):Bool = true;
	public var baseColor:FlxColor = FlxColor.BLACK;

	public function new(x:Float, y:Float, width:Int, height:Int, ?text:String = null, ?img:FlxGraphic = null, onClick:Void->Void = null, animWidth:Int = 0, animHeight:Int = 0)
	{
		super(x, y);

		bg = FlxSpriteUtil.drawRoundRect(new FlxSprite().makeGraphic(width, height, FlxColor.TRANSPARENT), 0, 0, width, height, 15, 15, FlxColor.WHITE);
		bg.color = FlxColor.BLACK;
		add(bg);

		if (text != null)
		{
			label = new FlxText(0, 0, width, text, 18);
			label.setFormat(Paths.font(ModsMenuState.FONT), 18, FlxColor.WHITE, CENTER);
			label.y = (height - label.height) / 2;
			add(label);
		}
		else if (img != null)
		{
			icon = new FlxSprite();
			if (animWidth > 0 || animHeight > 0) icon.loadGraphic(img, true, animWidth, animHeight);
			else icon.loadGraphic(img);
			centerOnBg(icon);
			add(icon);
		}

		this.onClick = onClick;
		setButtonVisibility(false);
	}

	public var focusChangeCallback:Bool->Void = null;
	public var onFocus(default, set):Bool = false;
	public var ignoreCheck:Bool = false;
	private var _needACheck:Bool = false;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!enabled)
		{
			onFocus = false;
			return;
		}

		if (!ignoreCheck && !Controls.instance.controllerMode && (FlxG.mouse.justPressed || FlxG.mouse.justMoved) && FlxG.mouse.visible)
			onFocus = FlxG.mouse.overlaps(this);

		if (onFocus && onClick != null && FlxG.mouse.justPressed)
			onClick();

		if (_needACheck)
		{
			_needACheck = false;
			if (!Controls.instance.controllerMode)
				setButtonVisibility(FlxG.mouse.overlaps(this));
		}
	}

	function set_onFocus(newValue:Bool)
	{
		var lastFocus:Bool = onFocus;
		onFocus = newValue;
		if (onFocus != lastFocus && enabled) setButtonVisibility(onFocus);
		return newValue;
	}

	function set_enabled(newValue:Bool)
	{
		enabled = newValue;
		setButtonVisibility(false);
		alpha = enabled ? 1 : 0.4;

		_needACheck = enabled;
		return newValue;
	}

	public function setButtonVisibility(focusVal:Bool)
	{
		alpha = 1;
		bg.color = focusVal ? FlxColor.WHITE : baseColor;
		bg.alpha = focusVal ? 0.8 : 0.6;

		var focusAlpha = focusVal ? 1 : 0.6;
		if (label != null)
		{
			label.alpha = focusAlpha;
			label.color = focusVal ? FlxColor.BLACK : FlxColor.WHITE;
		}
		else if (icon != null)
		{
			icon.alpha = focusAlpha;
			icon.color = focusVal ? FlxColor.BLACK : FlxColor.WHITE;
		}

		if (!enabled) alpha = 0.4;
		if (focusChangeCallback != null) focusChangeCallback(focusVal);
	}

	public function centerOnBg(spr:FlxSprite)
	{
		spr.x = bg.width / 2 - spr.width / 2;
		spr.y = bg.height / 2 - spr.height / 2;
	}
}

/**
 * Botón con imagen de 3 estados (normal / -highlighted / -inverted) en images/ui/mods/.
 * Usado por el botón DONE.
 */
class ModMenuButton extends FlxSprite
{
	public var graphicName:String;
	public var invert(default, set):Bool = false;
	public var selected(default, set):Bool = false;

	public function new(x:Float = 0, y:Float = 0, ?graphicName:String)
	{
		super(x, y);
		this.graphicName = graphicName;
		if (graphicName != null) loadTexture(graphicName);
	}

	function loadTexture(name:String):Void
	{
		if (!Paths.fileExists('images/ui/mods/$name.png', IMAGE)) return;
		loadGraphic(Paths.image('ui/mods/' + name));
		updateHitbox();
	}

	function refresh():Void
	{
		if (graphicName == null) return;
		if (invert) loadTexture(graphicName + '-inverted');
		else if (selected) loadTexture(graphicName + '-highlighted');
		else loadTexture(graphicName);
	}

	function set_invert(val:Bool):Bool
	{
		if (invert == val) return val;
		invert = val;
		refresh();
		return val;
	}

	function set_selected(val:Bool):Bool
	{
		if (selected == val) return val;
		selected = val;
		if (!invert) refresh();
		return val;
	}
}

/**
 * Chispas del mod menu. Necesita images/ui/mods/sparks.png + sparks.xml con prefijos
 * "spark 1" ... "spark 11", "electrocution" y "end". Si no existe el XML, no hace nada.
 */
class ModMenuSparks extends FlxSprite
{
	/** Punto (ms) del sonido de electrocución al terminar las chispas: 83 frames a 24 FPS. */
	public static final SHOCK_SOUND_END_TIME:Float = (83 / 24) * 1000;

	var ready:Bool = false;
	var _timer:FlxTimer = new FlxTimer();
	var _previousAnimation:String = '';
	var _randomAnimations:Array<String> = [];
	var shockSound:FlxSound = null;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		visible = false;

		if (!Paths.fileExists('images/ui/mods/sparks.xml', TEXT))
		{
			makeGraphic(1, 1, FlxColor.TRANSPARENT);
			return;
		}

		ready = true;
		frames = Paths.getSparrowAtlas('ui/mods/sparks');
		antialiasing = ClientPrefs.data.antialiasing;
		loadAnimations();
		startTimer();

		animation.finishCallback = function(name:String)
		{
			if (_randomAnimations.contains(name)) startTimer();
			visible = false;
		};
	}

	/** Electrocución en bucle hasta llamar a endElectrocution(). */
	public function startElectrocution():Void
	{
		if (!ready) return;
		if (_timer.active) _timer.cancel();

		visible = true;
		animation.play('electrocution', true);
		shockSound = ModsMenuState.playSnd('ui/mods/sounds/sparks/electrocution');
	}

	public function endElectrocution():Void
	{
		if (!ready) return;
		animation.play('end', true);
		if (shockSound != null) shockSound.time = SHOCK_SOUND_END_TIME;
	}

	public function playRandomAnimation():Void
	{
		var anim:String = getRandomAnimation();

		visible = true;
		animation.play(anim, true);
		ModsMenuState.playSnd('ui/mods/sounds/sparks/spark-' + anim);

		_previousAnimation = anim;
	}

	function startTimer():Void
	{
		_timer.start(FlxG.random.int(6, 20), function(_) playRandomAnimation());
	}

	function getRandomAnimation():String
	{
		if (_randomAnimations.length < 2) return _randomAnimations[0];

		var anim:String = _randomAnimations[FlxG.random.int(0, _randomAnimations.length - 1)];
		return (anim == _previousAnimation) ? getRandomAnimation() : anim;
	}

	function loadAnimations():Void
	{
		for (i in 1...12)
		{
			animation.addByPrefix('$i', 'spark $i', 24, false);
			_randomAnimations.push('$i');
		}

		animation.addByPrefix('electrocution', 'electrocution', 24, true);
		animation.addByPrefix('end', 'end', 24, false);
	}

	override public function destroy():Void
	{
		if (_timer.active) _timer.cancel();
		if (shockSound != null) shockSound.destroy();
		super.destroy();
	}
}

/**
 * Ambiente del mod menu: loop de fondo con fade in + sonidos aleatorios (lista opcional).
 */
class ModMenuAmbience
{
	public var baseAmbiencePath:String;
	public var randomSounds:Array<String>;
	public var randomSoundWait:Float = 7.0;
	public var minWait:Float = 6.0;
	public var maxWait:Float = 10.0;
	public var fadeInTime:Float = 4.0;
	public var volume:Float = 0.8;

	var _loop:FlxSound = null;
	var _fade:FlxTween = null;
	var _timer:FlxTimer = new FlxTimer();
	var _lastIndex:Int = -1;

	public function new(baseAmbiencePath:String, randomSounds:Array<String>)
	{
		this.baseAmbiencePath = baseAmbiencePath;
		this.randomSounds = randomSounds;
	}

	public function start():Void
	{
		if (ModsMenuState.soundExists(baseAmbiencePath))
		{
			_loop = FlxG.sound.load(Paths.sound(baseAmbiencePath), 0, true);
			_loop.play();
			_fade = FlxTween.num(0, volume, fadeInTime, null, function(v:Float) if (_loop != null) _loop.volume = v);
		}

		if (randomSounds != null && randomSounds.length > 0)
			_timer.start(randomSoundWait, function(_) playRandomSound());
	}

	function playRandomSound():Void
	{
		var i:Int = FlxG.random.int(0, randomSounds.length - 1);
		if (randomSounds.length > 1 && i == _lastIndex) i = (i + 1) % randomSounds.length;
		_lastIndex = i;
		ModsMenuState.playSnd(randomSounds[i]);

		_timer.start(FlxG.random.float(minWait, maxWait), function(_) playRandomSound());
	}

	public function stop(fadeOut:Float = 0.5):Void
	{
		_timer.cancel();
		if (_fade != null) _fade.cancel();
		if (_loop != null)
		{
			var l = _loop;
			FlxTween.num(l.volume, 0, fadeOut, {onComplete: function(_) l.stop()}, function(v:Float) l.volume = v);
		}
	}

	public function destroy():Void
	{
		_timer.destroy();
		if (_fade != null) _fade.cancel();
		if (_loop != null) _loop.destroy();
		_loop = null;
	}
}
