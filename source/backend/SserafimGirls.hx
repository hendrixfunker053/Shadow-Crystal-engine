package backend;

import flixel.FlxBasic;

import flixel.math.FlxMatrix;
import flixel.math.FlxMath;
import haxe.ds.StringMap;

import objects.Character;
import states.PlayState;

typedef GirlCfg =
{
	var idx:Int;
	var c:Character;
	var lip:FlxSprite;
	var fr:Dynamic;
	var sym:String;
	var yun:Bool;
	var cur:Array<Int>;
	var prevSym:Dynamic;
	var prevFrSym:Dynamic;
	var hiddenC:Array<Dynamic>;
	var hiddenFr:Array<Dynamic>;
	var lastAnim:String;
	var lastFr:Int;
	var wasFrontVis:Bool;
	var lastLipFrame:Int;
	var lastKeyAnim:String;
	var lastKeyFr:Int;
	var lastEntry:Dynamic;
	var lastLipX:Float;
	var lastLipY:Float;
	var lastLipAng:Float;
	var lastFrX:Float;
	var lastFrY:Float;
	var lastFrA:Float;
	var lastFrAng:Float;
	var lastFrFlipX:Bool;
	var lastFrFlipY:Bool;
	var offs:Map<String, Array<Int>>;
}

/**
 * Yunjin, Chaewon, Eunchae + bocas lip-sync 1:1 + capa de cabello frontal.
 * Portado de data/spaghetti/characters_lipsync.lua.
 *
 * Todo lo que toca internals de FlxAnimate va con Dynamic a proposito:
 * asi compila aunque tu version de FlxAnimate cambie campos privados.
 */
class SserafimGirls
{
	static final SING_ANIMS:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var yunjin:Character;
	public var chaewon:Character;
	public var eunchae:Character;
	public var yunjinIntro:FlxSprite;

	var game:PlayState;
	var chSh:Dynamic;

	var lipDad:FlxSprite;
	var lipBf:FlxSprite;
	var lipYunjin:FlxSprite;
	var lipChaewon:FlxSprite;
	var lipEunchae:FlxSprite;

	var cfgs:Array<GirlCfg> = [];
	var extras:Array<Character> = [];
	var chars:Array<Character> = [];

	var stdFrames:Array<Int> = [];
	var yunFrames:Array<Int> = [];

	var matPool:Array<FlxMatrix> = [];
	var mouthCache:StringMap<Dynamic> = new StringMap<Dynamic>();
	var identMat:FlxMatrix = new FlxMatrix();
	var resMat:FlxMatrix = new FlxMatrix();

	public var singing:Array<Bool> = [false, false, false, false, false, false]; // [0]=yunjin [1]=dad [2]=chaewon [3]=eunchae [4]=bf [5]=gf
	public var isBeautiful:Bool = false;
	public var yunjinVisible:Bool = true;

	var lastYiX:Float = -999999.0;
	var lastYiY:Float = -999999.0;

	// ---------------------------------------------------------------------------------------------
	// Capas Clipper de FlxAnimate (para que cabeza/pelo de GF queden detras del camion, etc.)
	// frontMode = true  -> estilo "limpiarSym" del stage (Clipper y Clipped ocultos y en Normal)
	// frontMode = false -> estilo "ocultarClippers" de las chicas (solo Clipper oculto, Clipped a Normal)
	// ---------------------------------------------------------------------------------------------
	public static function hideClipperLayers(spr:Dynamic, killClippedToo:Bool):Void
	{
		if (spr == null || spr.anim == null) return;
		if (spr.anim.metadata != null)
		{
			spr.anim.metadata.skipFilters = true;
			spr.anim.metadata.showHiddenLayers = false;
		}

		var clearSym = function(sym:Dynamic)
		{
			try {
			if (sym == null || sym.timeline == null) return;
			var normalType:Dynamic = null;
			var layers:Dynamic = sym.timeline.getList();
			for (layer in (layers : Array<Dynamic>))
			{
				if (layer == null) continue;
				var lt:String = (layer.type != null) ? Type.enumConstructor(layer.type) : '';
				if (killClippedToo)
				{
					// Igual que limpiarSym del stage .lua: Clipper, Clipped y capas con _clipper -> Normal + ocultas
					if (lt == 'Clipper' || lt == 'Clipped' || layer._clipper != null)
					{
						if (normalType == null && layer.type != null)
							normalType = Type.createEnum(Type.getEnum(layer.type), 'Normal');
						layer._clipper = null;
						if (normalType != null) layer.type = normalType;
						layer._correctClip = true;
						setVis(layer, false);
					}
				}
				else if (lt == 'Clipper')
				{
					layer._correctClip = true;
					setVis(layer, false);
				}
				else if (lt == 'Clipped' || layer._clipper != null)
				{
					if (normalType == null && layer.type != null)
						normalType = Type.createEnum(Type.getEnum(layer.type), 'Normal');
					layer._clipper = null;
					if (normalType != null) layer.type = normalType;
				}
			}
			} catch (e:Dynamic) { trace('[SserafimGirls] hideClipperLayers: ' + e); }
		};

		if (spr.anim.symbolDictionary != null)
		{
			var dict:Dynamic = spr.anim.symbolDictionary;
			for (sym in (dict : haxe.Constraints.IMap<String, Dynamic>))
				clearSym(sym);
		}
		clearSym(spr.anim.curSymbol);
	}

	// ---------------------------------------------------------------------------------------------

	public function new(game:PlayState, chSh:Dynamic)
	{
		this.game = game;
		this.chSh = chSh;
	}

	function makeLip(yunVar:Bool, flipped:Bool):FlxSprite
	{
		var w:Int = 47;
		var h:Int = yunVar ? 40 : 36;
		var bw:Float = 46.6632;
		var bh:Float = yunVar ? 39.6484 : 35.2032;
		var lip:FlxSprite = new FlxSprite();
		var g = Paths.image(yunVar ? 'sserafim-lipsync-yunjin-strip' : 'sserafim-lipsync-strip');
		if (g != null) lip.loadGraphic(g, true, w, h);
		else lip.makeGraphic(w, h, 0x00000000);
		lip.origin.set(bw * 0.5, bh * 0.5);
		lip.flipX = flipped;
		lip.antialiasing = ClientPrefs.data.antialiasing;
		lip.visible = false;
		if (chSh != null) lip.shader = chSh;
		return lip;
	}

	#if flxanimate
	function makeFrontAtlas(srcChar:Character, imgPath:String):Dynamic
	{
		if (srcChar == null || !srcChar.isAnimateAtlas) return null;
		var fr = new FlxAnimate(srcChar.x, srcChar.y);
		fr.showPivot = false;
		Paths.loadAnimateAtlas(fr, imgPath);
		for (anim in srcChar.animationsArray)
		{
			if (anim.indices != null && anim.indices.length > 0)
				fr.anim.addBySymbolIndices(anim.anim, anim.name, anim.indices, anim.fps, anim.loop);
			else
				fr.anim.addBySymbol(anim.anim, anim.name, anim.fps, anim.loop);
		}
		hideClipperLayers(fr, false);
		fr.active = false;
		fr.visible = false;
		if (chSh != null) fr.shader = chSh;
		return fr;
	}
	#end

	function newCfg(idx:Int, c:Character, lip:FlxSprite, fr:Dynamic, sym:String, yun:Bool, cur:Array<Int>, offs:Map<String, Array<Int>>):GirlCfg
	{
		return {
			idx: idx, c: c, lip: lip, fr: fr, sym: sym, yun: yun, cur: cur,
			prevSym: null, prevFrSym: null, hiddenC: [], hiddenFr: [],
			lastAnim: '', lastFr: -999, wasFrontVis: false, lastLipFrame: -1,
			lastKeyAnim: '', lastKeyFr: -999, lastEntry: null,
			lastLipX: -999999.0, lastLipY: -999999.0, lastLipAng: -999999.0,
			lastFrX: -999999.0, lastFrY: -999999.0, lastFrA: -1.0, lastFrAng: -999999.0,
			lastFrFlipX: false, lastFrFlipY: false, offs: offs
		};
	}

	/**
	 * Crea todo. `stool` es el sprite frontStool: lo de las chicas se inserta justo antes.
	 * `introSpr` es el sprite pre-bakeado de Yunjin detras de la puerta (yunjinIntro).
	 */
	public function create(stool:FlxBasic, introSpr:FlxSprite):Void
	{
		yunjinIntro = introSpr;

		for (i in 0...SserafimLipMaps.STD.length) stdFrames.push(SserafimLipMaps.STD.charCodeAt(i) - 65);
		for (i in 0...SserafimLipMaps.YUN.length) yunFrames.push(SserafimLipMaps.YUN.charCodeAt(i) - 65);
		for (_ in 0...16) matPool.push(new FlxMatrix());

		if (game == null) return;
		var dad = game.dad;
		var bf = game.boyfriend;

		// Atlas de Sakura/Kazuha con width <= 0 -> valores por defecto
		#if flxanimate
		if (bf != null && bf.isAnimateAtlas && bf.atlas != null && bf.atlas.width <= 0)
		{
			bf.atlas.width = 590.84;
			bf.atlas.height = 683.15;
		}
		if (game.gf != null && game.gf.isAnimateAtlas) hideClipperLayers(game.gf.atlas, false);
		#end

		yunjin = new Character(0, 0, 'sserafim-yunjin', false);
		yunjin.setPosition(-621 + yunjin.positionArray[0], 154 + yunjin.positionArray[1]);
		yunjin.scrollFactor.set(0.95, 0.95);
		yunjin.danceEveryNumBeats = 0;
		yunjin.playAnim('doorclosed', true);
		if (chSh != null) yunjin.shader = chSh;
		#if flxanimate
		if (yunjin.isAnimateAtlas) hideClipperLayers(yunjin.atlas, false);
		#end

		chaewon = new Character(0, 0, 'sserafim-chaewon', false);
		chaewon.setPosition(687 + chaewon.positionArray[0], 98 + chaewon.positionArray[1]);
		chaewon.scrollFactor.set(0.95, 0.95);
		if (chSh != null) chaewon.shader = chSh;

		eunchae = new Character(0, 0, 'sserafim-eunchae', false);
		eunchae.setPosition(770 + eunchae.positionArray[0], 675 + eunchae.positionArray[1]);
		eunchae.scrollFactor.set(0.97, 0.97);
		if (chSh != null) eunchae.shader = chSh;

		lipDad = makeLip(false, true);
		lipBf = makeLip(false, true);
		lipYunjin = makeLip(true, false);
		lipChaewon = makeLip(false, false);
		lipEunchae = makeLip(false, false);

		var frontBf:Dynamic = null;
		var frontYunjin:Dynamic = null;
		var frontChaewon:Dynamic = null;
		var frontEunchae:Dynamic = null;
		#if flxanimate
		frontBf = makeFrontAtlas(bf, 'characters/sserafim/sakura');
		frontYunjin = makeFrontAtlas(yunjin, 'characters/sserafim/yunjin');
		frontChaewon = makeFrontAtlas(chaewon, 'characters/sserafim/chaewon');
		frontEunchae = makeFrontAtlas(eunchae, 'characters/sserafim/eunchae');
		#end

		if (chSh != null && introSpr != null) introSpr.shader = chSh;

		// Orden visual: dad->lip, bf->lip->front, yunjinIntro/yunjin->lip->front, chaewon, eunchae antes de frontStool
		var state = FlxG.state;
		function insertAfter(anchor:FlxBasic, obj:FlxBasic):FlxBasic
		{
			if (anchor == null || obj == null) return anchor;
			var i = state.members.indexOf(anchor);
			if (i >= 0) state.insert(i + 1, obj);
			else state.add(obj);
			return obj;
		}
		function insertBeforeStool(obj:FlxBasic):Void
		{
			if (obj == null) return;
			var sIdx = (stool != null) ? state.members.indexOf(stool) : -1;
			if (sIdx >= 0) state.insert(sIdx, obj);
			else state.add(obj);
		}

		insertAfter(game.dadGroup, lipDad);
		var p = insertAfter(game.boyfriendGroup, lipBf);
		insertAfter(p, frontBf);

		if (introSpr != null)
		{
			state.remove(introSpr, true);
			insertBeforeStool(introSpr);
		}
		insertBeforeStool(yunjin);
		insertBeforeStool(lipYunjin);
		insertBeforeStool(frontYunjin);

		insertBeforeStool(chaewon);
		insertBeforeStool(lipChaewon);
		insertBeforeStool(frontChaewon);

		insertBeforeStool(eunchae);
		insertBeforeStool(lipEunchae);
		insertBeforeStool(frontEunchae);

		#if flxanimate
		for (obj in [dad, bf, yunjin, chaewon, eunchae])
			if (obj != null && obj.isAnimateAtlas && obj.atlas != null && obj.atlas.anim != null && obj.atlas.anim.metadata != null)
				obj.atlas.anim.metadata.showHiddenLayers = false;
		#end

		// Offsets de boca por animacion (x, y, angulo)
		var dadOffs:Map<String, Array<Int>> = [
			'idle' => [5, 4, -13], 'singUP' => [7, 2, -14], 'singRIGHT' => [7, 2, -13], 'singDOWN' => [4, 6, -12], 'singLEFT' => [5, 4, -14],
			'singUPmiss' => [7, 2, -14], 'singRIGHTmiss' => [7, 2, -13], 'singDOWNmiss' => [4, 6, -12], 'singLEFTmiss' => [5, 4, -14]
		];
		var bfOffs:Map<String, Array<Int>> = [
			'idle' => [7, 2, -14], 'singUP' => [8, 1, -15], 'singRIGHT' => [7, 2, -15], 'singDOWN' => [6, 3, -15], 'singLEFT' => [7, 2, -14],
			'singUP-joint' => [10, -1, -14], 'singRIGHT-joint' => [6, 3, -15], 'singDOWN-joint' => [5, 5, -15], 'singLEFT-joint' => [7, 2, -16],
			'singUPmiss' => [8, 1, -15], 'singRIGHTmiss' => [7, 2, -15], 'singDOWNmiss' => [6, 3, -15], 'singLEFTmiss' => [7, 2, -14],
			'singUPmiss-joint' => [10, -1, -14], 'singRIGHTmiss-joint' => [6, 3, -15], 'singDOWNmiss-joint' => [5, 5, -15], 'singLEFTmiss-joint' => [7, 2, -16],
			'singUP-bf1' => [7, 2, -14], 'singRIGHT-bf1' => [7, 2, -14], 'singDOWN-bf1' => [7, 2, -14], 'singLEFT-bf1' => [7, 2, -14],
			'singUP-bf2' => [7, 2, -14], 'singRIGHT-bf2' => [7, 2, -14], 'singDOWN-bf2' => [7, 2, -14], 'singLEFT-bf2' => [7, 2, -14],
			'singUPmiss-bf2' => [7, 2, -14], 'singRIGHTmiss-bf2' => [7, 2, -14], 'singDOWNmiss-bf2' => [7, 2, -14], 'singLEFTmiss-bf2' => [7, 2, -14]
		];
		var yunOffs:Map<String, Array<Int>> = [
			'idle' => [8, 6, 23], 'singUP' => [6, 8, 22], 'singRIGHT' => [6, 8, 23], 'singDOWN' => [8, 6, 23], 'singLEFT' => [6, 8, 23],
			'singUPmiss' => [6, 8, 22], 'singRIGHTmiss' => [6, 8, 23], 'singDOWNmiss' => [8, 6, 23], 'singLEFTmiss' => [6, 8, 23]
		];
		var chaOffs:Map<String, Array<Int>> = [
			'idle' => [41, 3, -166], 'singUP' => [38, 0, -168], 'singRIGHT' => [39, 1, -165], 'singDOWN' => [41, 3, -167], 'singLEFT' => [40, 2, -165],
			'singUPmiss' => [38, 0, -168], 'singRIGHTmiss' => [39, 1, -165], 'singDOWNmiss' => [41, 3, -167], 'singLEFTmiss' => [40, 2, -165]
		];
		var eunOffs:Map<String, Array<Int>> = [
			'idle' => [43, 6, -168], 'singUP' => [45, 10, -166], 'singRIGHT' => [42, 5, -166], 'singDOWN' => [41, 3, -168], 'singLEFT' => [43, 6, -169],
			'singUPmiss' => [45, 10, -166], 'singRIGHTmiss' => [42, 5, -166], 'singDOWNmiss' => [41, 3, -168], 'singLEFTmiss' => [43, 6, -169]
		];

		cfgs = [
			newCfg(1, dad, lipDad, null, 'mouth default', false, [5, 4, -13], dadOffs),
			newCfg(4, bf, lipBf, frontBf, 'mouth edit', false, [7, 2, -14], bfOffs),
			newCfg(0, yunjin, lipYunjin, frontYunjin, 'mouth yunjin', true, [8, 6, 23], yunOffs),
			newCfg(2, chaewon, lipChaewon, frontChaewon, 'mouth default', false, [41, 3, -166], chaOffs),
			newCfg(3, eunchae, lipEunchae, frontEunchae, 'mouth default', false, [43, 6, -168], eunOffs)
		];

		extras = [yunjin, chaewon, eunchae];
		chars = [yunjin, dad, chaewon, eunchae, bf, game.gf];

		setVisibility(true, false, false, false, false);
	}

	// ---------------------------------------------------------------------------------------------
	// API publica (antes: funciones Lua llamadas con callOnLuas / runHaxeFunction)
	// ---------------------------------------------------------------------------------------------

	public function setVisibility(v0:Bool, v1:Bool, v2:Bool, v3:Bool, v4:Bool):Void
	{
		yunjinVisible = v0;
		if (yunjin != null) yunjin.visible = v0;
		if (yunjinIntro != null && !v0) yunjinIntro.visible = false;
		if (game != null && game.dad != null) game.dad.visible = v1;
		if (chaewon != null) chaewon.visible = v2;
		if (eunchae != null) eunchae.visible = v3;
		if (game != null && game.boyfriend != null) game.boyfriend.visible = v4;
	}

	public function setSinging(arr:Array<Bool>):Void
	{
		for (i in 0...6) singing[i] = (i < arr.length) ? arr[i] : false;
	}

	public function yunjinAnim(animName:String, isSpecial:Bool, beats:Int):Void
	{
		if (yunjin == null) return;
		yunjin.danceEveryNumBeats = beats;
		yunjin.playAnim(animName, true);
		yunjin.specialAnim = isSpecial;
	}

	public function resetYunjinDoor():Void yunjinAnim('doorclosed', false, 0);
	public function yunjinKickFirst():Void yunjinAnim('kick1', false, 0);
	public function yunjinKickFinal():Void yunjinAnim('kick2', true, 1);

	public function setBeautiful(b:Bool):Void
	{
		isBeautiful = b;
		if (game != null && game.gf != null)
		{
			game.gf.idleSuffix = b ? '-beautiful' : '';
			game.gf.dance();
		}
	}

	/** Baile de las chicas extra al compas */
	public function beat(curBeat:Int):Void
	{
		for (extra in extras)
		{
			if (extra == null || extra.isAnimationNull()) continue;
			var curA = extra.getAnimationName();
			if (!StringTools.startsWith(curA, 'sing') && !extra.specialAnim && !extra.stunned
				&& extra.danceEveryNumBeats > 0 && curBeat % extra.danceEveryNumBeats == 0)
				extra.dance();
		}
	}

	/** Nota acertada / fallada -> cantan los personajes marcados con sserafimSing */
	public function sing(noteData:Int, noteType:String, isMiss:Bool):Void
	{
		if (chars.length < 6) return;
		var baseAnim:String = SING_ANIMS[Std.int(Math.abs(noteData)) % 4];
		if (baseAnim == null) baseAnim = 'singLEFT';
		if (isMiss) baseAnim += 'miss';

		var animBf:String = baseAnim;
		if (noteType == 'sakura-joint') animBf = baseAnim + '-joint';
		else if (noteType == 'sakura-bf1') animBf = baseAnim + (isMiss ? '-bf2' : '-bf1');
		else if (noteType == 'sakura-bf2') animBf = baseAnim + '-bf2';

		var animGf:String = isBeautiful ? (baseAnim + '-beautiful') : baseAnim;
		var bfForce:Bool = (noteType != null && noteType.substr(0, 7) == 'sakura-');

		for (i in 0...6)
		{
			var c = chars[i];
			if (c == null) continue;
			var active = singing[i] || (i == 4 && bfForce);
			if (!active) continue;
			var target = (i == 4) ? animBf : ((i == 5) ? animGf : baseAnim);
			if (c.hasAnimation(target))
			{
				c.specialAnim = false;
				c.playAnim(target, true);
				c.holdTimer = 0;
			}
			else if (c.hasAnimation(baseAnim))
			{
				c.specialAnim = false;
				c.playAnim(baseAnim, true);
				c.holdTimer = 0;
			}
		}
	}

	// ---------------------------------------------------------------------------------------------
	// Lip-sync + capa frontal (cada frame)
	// ---------------------------------------------------------------------------------------------

	function restoreLayers(cfg:GirlCfg):Void
	{
		if (cfg.hiddenC.length > 0)
		{
			for (l in cfg.hiddenC) if (l != null) setVis(l, true);
			cfg.hiddenC.resize(0);
		}
		if (cfg.hiddenFr.length > 0)
		{
			for (l in cfg.hiddenFr) if (l != null) setVis(l, true);
			cfg.hiddenFr.resize(0);
		}
		cfg.prevSym = null;
		cfg.prevFrSym = null;
	}

	/** Set de frame sin acceso Dynamic directo a la propiedad `curFrame` (hxcpp lanza "Invalid field:curFrame"). */
	static function setAnimFrame(fr:Dynamic, f:Int):Void
	{
		try
		{
			if (fr.anim.curInstance != null && fr.anim.curInstance.symbol != null)
				fr.anim.curInstance.symbol._curFrame = f;
		}
		catch (e:Dynamic) {}
		try { Reflect.setProperty(fr.anim, 'curFrame', f); } catch (e:Dynamic) {}
	}

	/**
	 * Devuelve el frame ABSOLUTO del timeline raiz (donde vive la boca).
	 * Segun la version de FlxAnimate, `symbol._curFrame` puede ser absoluto o relativo a `indices`:
	 * - si cae dentro del rango [primer indice, ultimo indice] ya es absoluto;
	 * - si no, y cabe en la lista de indices, es relativo y se traduce.
	 */
	function absoluteFrame(c:Character, animName:String, cur:Int):Int
	{
		if (c == null || c.animationsArray == null) return cur;
		for (a in c.animationsArray)
		{
			if (a.anim == animName)
			{
				var ind = a.indices;
				if (ind == null || ind.length == 0) return cur;
				var lo:Int = ind[0];
				var hi:Int = ind[ind.length - 1];
				if (cur >= lo && cur <= hi) return cur;
				if (cur >= 0 && cur < ind.length) return ind[cur];
				return cur;
			}
		}
		return cur;
	}

	static function setVis(o:Dynamic, v:Bool):Void
	{
		try { o.visible = v; }
		catch (e:Dynamic) { Reflect.setProperty(o, 'visible', v); }
	}

	var frontErrors:Int = 0;

	/** Un fallo en la capa frontal (pelo) NO debe apagar el lip-sync: se aisla y solo desactiva la capa. */
	function frontError(cfg:GirlCfg, e:Dynamic):Void
	{
		frontErrors++;
		trace('[SserafimGirls] capa frontal idx' + cfg.idx + ' (' + frontErrors + '/5): ' + e);
		try { restoreLayers(cfg); } catch (_:Dynamic) {}
		if (frontErrors >= 5)
		{
			for (g in cfgs)
			{
				try { if (g.fr != null) g.fr.visible = false; } catch (_:Dynamic) {}
				g.fr = null;
			}
		}
	}

	function findMouth(anim:Dynamic, instance:Dynamic, parentMat:FlxMatrix, frameOffset:Int, targetSubstr:String, outMat:FlxMatrix, depth:Int, outCtx:{poseSymName:String, layerIdx:Int}):Bool
	{
		if (anim == null || instance == null || depth > 12 || instance.symbol == null) return false;
		var sym:Dynamic = anim.symbolDictionary.get(instance.symbol.name);
		if (sym == null) return false;

		var curMat = matPool[depth];
		curMat.copyFrom(instance.matrix);
		curMat.translate(instance.x, instance.y);
		curMat.concat(parentMat);

		var symName:String = instance.symbol.name;
		if (symName != null && symName.toLowerCase().indexOf(targetSubstr) >= 0)
		{
			outMat.copyFrom(curMat);
			return true;
		}

		var symLen:Int = sym.length > 0 ? Std.int(sym.length) : 1;
		var loopName:String = (instance.symbol.loop != null) ? Std.string(instance.symbol.loop) : '';
		var typeName:String = (instance.symbol.type != null) ? Std.string(instance.symbol.type) : '';
		var curFF:Int = frameOffset;
		if (depth > 0)
		{
			var first:Int = Std.int(instance.symbol.firstFrame);
			if (loopName == 'Loop') curFF = (frameOffset + first) % symLen;
			else if (loopName == 'PlayOnce') curFF = Std.int(FlxMath.bound(frameOffset + first, 0, symLen - 1));
			else curFF = first;
		}
		if (typeName == 'MovieClip') curFF = 0;

		var layers:Array<Dynamic> = sym.timeline.getList();
		for (li in 0...layers.length)
		{
			var layer:Dynamic = layers[li];
			if (layer == null || !layer.visible) continue;
			var kf:Dynamic = layer.get(curFF);
			if (kf == null) continue;
			var relFrame:Int = curFF - Std.int(kf.index);
			if (relFrame < 0) relFrame = 0;
			var els:Array<Dynamic> = kf.getList();
			for (el in els)
			{
				if (el != null && el.symbol != null)
				{
					if (findMouth(anim, el, curMat, relFrame, targetSubstr, outMat, depth + 1, outCtx))
					{
						if (outCtx != null && outCtx.poseSymName == null)
						{
							outCtx.poseSymName = sym.name;
							outCtx.layerIdx = li;
						}
						return true;
					}
				}
			}
		}
		return false;
	}

	/** Igual que el bloque "no visible / sin boca" del Lua: restaura capas y oculta boca + capa frontal. */
	function hideCfg(cfg:GirlCfg):Void
	{
		if (cfg.wasFrontVis || cfg.hiddenC.length > 0 || cfg.hiddenFr.length > 0) restoreLayers(cfg);
		if (cfg.lip != null && cfg.lip.visible) cfg.lip.visible = false;
		if (cfg.fr != null && cfg.fr.visible) cfg.fr.visible = false;
		cfg.wasFrontVis = false;
	}

	var updateErrors:Int = 0;

	/** DEBUG: muestra en pantalla el estado de cada chica (frame, anim, si se encontro la boca). */
	public var debug:Bool = true;
	var dbg:String = '';

	/** Opcional: el stage se suscribe para mostrar el error en pantalla. */
	public var onError:String->Void = null;

	/** Envuelve el lip-sync para que un error raro de FlxAnimate no tumbe el juego. Nunca se desactiva. */
	public function update():Void
	{
		if (debug) dbg = 'rawT=' + Math.floor((Conductor.songPosition / 1000.0) * 24.0) + ' sing=' + singing.join(',');
		try { updateInner(); }
		catch (e:Dynamic) { report('update', e); }
		if (debug && onError != null) onError(dbg);
	}

	function report(where:String, e:Dynamic):Void
	{
		updateErrors++;
		if (updateErrors > 20) return;
		trace('[SserafimGirls] ' + where + ': ' + Std.string(e));
		if (onError != null) onError('Lip-sync ' + where + ': ' + Std.string(e));
	}

	/** Un error en una chica NO debe impedir que las demas se procesen. */
	function girlError(cfg:GirlCfg, e:Dynamic):Void
	{
		report('idx' + cfg.idx, e);
		try { hideCfg(cfg); } catch (_:Dynamic) {}
		cfg.lastEntry = null;
		cfg.lastKeyFr = -999;
	}

	function updateInner():Void
	{
		#if flxanimate
		var inCut:Bool = game.inCutscene;
		var rawT:Int = Math.floor((Conductor.songPosition / 1000.0) * 24.0) - 1;
		var idxStd:Int = (rawT < 0) ? 0 : ((rawT >= stdFrames.length) ? stdFrames.length - 1 : rawT);
		var idxYun:Int = (rawT < 0) ? 0 : ((rawT >= yunFrames.length) ? yunFrames.length - 1 : rawT);
		var stdFr:Int = stdFrames[idxStd];
		var yunFr:Int = yunFrames[idxYun];

		// Swap de Yunjin en puerta por yunjinIntro pre-bakeado
		var yunjinUsandoIntro:Bool = false;
		var yiSpr = yunjinIntro;
		try
		{
		if (yunjin != null && yiSpr != null && yunjinVisible && !yunjin.isAnimationNull())
		{
			var curA:String = yunjin.getAnimationName();
			if (curA == 'doorclosed' || curA == 'kick1' || curA == 'kick2')
			{
				yunjinUsandoIntro = true;
				var cf:Int = 0;
				if (yunjin.isAnimateAtlas && yunjin.atlas != null && yunjin.atlas.anim != null)
				{
					var ai:Dynamic = yunjin.atlas.anim;
					if (ai.curInstance != null && ai.curInstance.symbol != null) cf = Std.int(ai.curInstance.symbol._curFrame);
				}
				if (yiSpr.animation.curAnim == null || yiSpr.animation.curAnim.name != curA)
				{
					yiSpr.animation.play(curA, true, false, cf);
					yiSpr.animation.pause();
				}
				else if (cf >= 0 && cf < yiSpr.animation.curAnim.numFrames && yiSpr.animation.curAnim.curFrame != cf)
					yiSpr.animation.curAnim.curFrame = cf;

				var yx:Float = yunjin.x - yunjin.offset.x - 7.0;
				var yy:Float = yunjin.y - yunjin.offset.y + 154.0;
				if (yx != lastYiX || yy != lastYiY)
				{
					yiSpr.setPosition(yx, yy);
					lastYiX = yx;
					lastYiY = yy;
				}
				if (yiSpr.alpha != yunjin.alpha) yiSpr.alpha = yunjin.alpha;
				if (yiSpr.shader != yunjin.shader) yiSpr.shader = yunjin.shader;
				if (yiSpr.cameras != yunjin.cameras) yiSpr.cameras = yunjin.cameras;
				if (yiSpr.visible != !inCut) yiSpr.visible = !inCut;
				if (yunjin.visible) yunjin.visible = false;
			}
			else
			{
				if (yiSpr.visible) yiSpr.visible = false;
				if (!yunjin.visible) yunjin.visible = true;
			}
		}
		else
		{
			if (yiSpr != null && yiSpr.visible) yiSpr.visible = false;
			if (yunjin != null && yunjin.visible != yunjinVisible) yunjin.visible = yunjinVisible;
		}
		}
		catch (e:Dynamic) { report('yunjinIntro', e); }

		for (ci in 0...cfgs.length)
		{
			var cfg:GirlCfg = cfgs[ci];
			try
			{
			var c:Character = cfg.c;
			var lip:FlxSprite = cfg.lip;
			var fr:Dynamic = cfg.fr;

			var charVis:Bool = (!inCut && c != null && c.exists && c.visible && c.alpha > 0.01 && c.isAnimateAtlas
				&& c.atlas != null && c.atlas.anim != null && c.atlas.anim.curInstance != null && c.atlas.anim.curInstance.symbol != null);

			if (debug) dbg += '\ni' + cfg.idx + ' vis=' + charVis + ' anim=' + ((c != null && !c.isAnimationNull()) ? c.getAnimationName() : '-');

			if (!charVis || (cfg.idx == 0 && yunjinUsandoIntro))
			{
				hideCfg(cfg);
				continue;
			}

			var inst:Dynamic = c.atlas.anim.curInstance;
			// CRITICO: usar inst.symbol._curFrame (frame exacto que dibuja FlxAnimate), no anim.curFrame
			var curFr:Int = Std.int(inst.symbol._curFrame);
			var animName:String = c.getAnimationName();
			if (animName == null) animName = '';

			var entry:Dynamic = (cfg.lastEntry != null && cfg.lastKeyFr == curFr && cfg.lastKeyAnim == animName) ? cfg.lastEntry : null;
			if (entry == null)
			{
				var cacheKey:String = cfg.idx + '|' + animName + '|' + curFr;
				entry = mouthCache.get(cacheKey);
				if (entry == null)
				{
					restoreLayers(cfg);
					var ctx = {poseSymName: (null : String), layerIdx: -1};
					// El timeline raiz (donde vive la boca) usa frames ABSOLUTOS; _curFrame puede ser relativo a `indices`
					var lookFr:Int = absoluteFrame(c, animName, curFr);
					var found:Bool = findMouth(c.atlas.anim, inst, identMat, lookFr, cfg.sym, resMat, 0, ctx);
					if (!found && cfg.idx == 4)
					{
						ctx.poseSymName = null;
						ctx.layerIdx = -1;
						found = findMouth(c.atlas.anim, inst, identMat, lookFr, 'mouth default', resMat, 0, ctx);
					}
					entry = {
						found: found,
						rawTx: resMat.tx,
						rawTy: resMat.ty,
						rawA: resMat.a,
						rawB: resMat.b,
						poseSymName: ctx.poseSymName,
						layerIdx: ctx.layerIdx
					};
					mouthCache.set(cacheKey, entry);
				}
				cfg.lastKeyAnim = animName;
				cfg.lastKeyFr = curFr;
				cfg.lastEntry = entry;
			}

			if (debug) dbg += ' cur=' + curFr + ' abs=' + absoluteFrame(c, animName, curFr) + ' found=' + entry.found + ' lay=' + entry.layerIdx;

			if (!entry.found)
			{
				hideCfg(cfg);
				continue;
			}

			var tx:Float = entry.rawTx;
			if (c.flipX)
			{
				var atlasW:Float = (c.atlas.width > 0) ? c.atlas.width : 590.84;
				tx = atlasW - tx;
			}

			if (cfg.offs.exists(animName)) cfg.cur = cfg.offs.get(animName);

			var worldX:Float = c.x - c.offset.x + tx;
			var worldY:Float = c.y - c.offset.y + entry.rawTy;
			var headDeg:Float = Math.atan2(entry.rawB, c.flipX ? -entry.rawA : entry.rawA) * 180.0 / Math.PI;
			var isSinging:Bool = singing[cfg.idx];

			if (lip != null)
			{
				if (!lip.visible) lip.visible = true;
				if (lip.scrollFactor.x != c.scrollFactor.x || lip.scrollFactor.y != c.scrollFactor.y)
					lip.scrollFactor.set(c.scrollFactor.x, c.scrollFactor.y);
				if (lip.shader != c.shader) lip.shader = c.shader;
				if (lip.cameras != c.cameras) lip.cameras = c.cameras;
				var targetLipFr:Int = isSinging ? (cfg.yun ? yunFr : stdFr) : 0;
				// FIX: si el strip de la boca no cargo (1 solo frame) o la letra se sale de rango, no crashear
				if (targetLipFr < 0 || targetLipFr >= lip.numFrames) targetLipFr = 0;
				if (cfg.lastLipFrame != targetLipFr)
				{
					lip.animation.frameIndex = targetLipFr;
					cfg.lastLipFrame = targetLipFr;
				}
				var targetAng:Float = headDeg + cfg.cur[2];
				if (cfg.lastLipAng != targetAng)
				{
					lip.angle = targetAng;
					cfg.lastLipAng = targetAng;
				}
				var lx:Float = worldX - cfg.cur[0];
				var ly:Float = worldY - cfg.cur[1];
				if (cfg.lastLipX != lx || cfg.lastLipY != ly)
				{
					lip.setPosition(lx, ly);
					cfg.lastLipX = lx;
					cfg.lastLipY = ly;
				}
			}

			try
			{
			var poseSym:Dynamic = (entry.poseSymName != null) ? c.atlas.anim.symbolDictionary.get(entry.poseSymName) : null;
			var layerIdx:Int = entry.layerIdx;
			if (fr != null && poseSym != null && layerIdx > 0 && poseSym.timeline != null)
			{
				var layers:Array<Dynamic> = poseSym.timeline.getList();
				if (layerIdx < layers.length)
				{
					var frSym:Dynamic = fr.anim.symbolDictionary.get(poseSym.name);
					var poseChanged:Bool = (!cfg.wasFrontVis || cfg.lastAnim != animName || cfg.lastFr != curFr || cfg.prevSym != poseSym);
					if (poseChanged)
					{
						restoreLayers(cfg);
						if (animName != '')
						{
							if (!cfg.wasFrontVis || cfg.lastAnim != animName)
								fr.anim.play(animName, true, false, curFr);
							else if (cfg.lastFr != curFr)
							{
								setAnimFrame(fr, curFr);
							}
							fr.anim.pause();
							fr.anim.update(0);
						}

						for (i in 0...layerIdx)
						{
							if (layers[i] != null && layers[i].visible)
							{
								setVis(layers[i], false);
								cfg.hiddenC.push(layers[i]);
							}
						}
						cfg.prevSym = poseSym;

						if (frSym != null && frSym.timeline != null)
						{
							var fls:Array<Dynamic> = frSym.timeline.getList();
							for (i in layerIdx...fls.length)
							{
								if (fls[i] != null && fls[i].visible)
								{
									setVis(fls[i], false);
									cfg.hiddenFr.push(fls[i]);
								}
							}
							cfg.prevFrSym = frSym;
						}
						cfg.lastAnim = animName;
						cfg.lastFr = curFr;
					}

						try { if (fr.cameras != c.cameras) fr.cameras = c.cameras; } catch (_:Dynamic) {}
					if (fr.scrollFactor.x != c.scrollFactor.x || fr.scrollFactor.y != c.scrollFactor.y)
						fr.scrollFactor.set(c.scrollFactor.x, c.scrollFactor.y);
					if (fr.scale.x != c.scale.x || fr.scale.y != c.scale.y)
						fr.scale.set(c.scale.x, c.scale.y);
					if (fr.offset.x != c.offset.x || fr.offset.y != c.offset.y)
						fr.offset.set(c.offset.x, c.offset.y);
					if (fr.origin.x != c.origin.x || fr.origin.y != c.origin.y)
						fr.origin.set(c.origin.x, c.origin.y);
					if (cfg.lastFrX != c.x || cfg.lastFrY != c.y)
					{
						fr.setPosition(c.x, c.y);
						cfg.lastFrX = c.x;
						cfg.lastFrY = c.y;
					}
					if (cfg.lastFrAng != c.angle) { fr.angle = c.angle; cfg.lastFrAng = c.angle; }
					if (cfg.lastFrA != c.alpha) { fr.alpha = c.alpha; cfg.lastFrA = c.alpha; }
					if (cfg.lastFrFlipX != c.flipX) { fr.flipX = c.flipX; cfg.lastFrFlipX = c.flipX; }
					if (cfg.lastFrFlipY != c.flipY) { fr.flipY = c.flipY; cfg.lastFrFlipY = c.flipY; }
					if (fr.shader != c.shader) fr.shader = c.shader;
					if (fr.antialiasing != c.antialiasing) fr.antialiasing = c.antialiasing;
					if (fr.color != c.color) fr.color = c.color;
					// CRITICO para Sakura (flipX=true): FlxAnimate.draw() usa fr.width como pivote horizontal
					if (c.flipX)
					{
						var aw:Float = (c.atlas.width > 0) ? c.atlas.width : 590.84;
						if (fr.width != aw) fr.width = aw;
					}
					if (!fr.visible) fr.visible = true;
					cfg.wasFrontVis = true;
				}
				else
				{
					if (cfg.wasFrontVis || cfg.hiddenC.length > 0 || cfg.hiddenFr.length > 0) restoreLayers(cfg);
					if (fr.visible) fr.visible = false;
					cfg.wasFrontVis = false;
				}
			}
			else
			{
				if (cfg.wasFrontVis || cfg.hiddenC.length > 0 || cfg.hiddenFr.length > 0) restoreLayers(cfg);
				if (fr != null && fr.visible) fr.visible = false;
				cfg.wasFrontVis = false;
			}
			}
			catch (e:Dynamic) { frontError(cfg, e); }
			}
			catch (e:Dynamic) { girlError(cfg, e); }
		}
		#end
	}
}
