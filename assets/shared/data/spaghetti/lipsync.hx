// LE SSERAFIM - Spaghetti: lip-sync + chicas extra (Yunjin, Chaewon, Eunchae) + capa frontal de cabello.
// Portado 1:1 de characters_lipsync.lua. Corre como HScript (igual que el mod oficial), fuera del stage.
// El stage (Sserafim.hx) solo registra en game.variables: frontStool, yunjinIntroSpr, sserCharShader, sserGirlsVis.
import flixel.math.FlxMatrix;
import flixel.math.FlxMath;
import haxe.ds.StringMap;

var isBeautiful = false;
var SING_ANIMS = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

// Puntos de entrada hacia las funciones que se crean en onCreatePost
var fUpdate = null;
var fVis = null;
var fYun = null;
var fSing = null;
var fBeat = null;
var fCantar = null;

function _boolArr(v1, key) {
	if (v1 == null) return null;
	var k = v1.indexOf('"' + key + '"');
	if (k < 0) return null;
	var a = v1.indexOf('[', k);
	var b = v1.indexOf(']', a);
	if (a < 0 || b < 0) return null;
	var out = [];
	for (p in v1.substr(a + 1, b - a - 1).split(',')) out.push(StringTools.trim(p) == 'true');
	return out;
}

function _boolField(v1, key) {
	if (v1 == null) return false;
	var k = v1.indexOf('"' + key + '"');
	if (k < 0) return false;
	var c = v1.indexOf(':', k);
	if (c < 0) return false;
	return StringTools.startsWith(StringTools.ltrim(v1.substr(c + 1)), 'true');
}

// ---- API que usa el stage (equivalente a las funciones Lua) ----
function visibilidadChicas(vis) {
	if (vis == null || vis.length < 5) return;
	game.variables.set('sserGirlsVis', vis);
	if (fVis != null) fVis(vis[0] == true, vis[1] == true, vis[2] == true, vis[3] == true, vis[4] == true);
}
function resetYunjinPuerta() { if (fYun != null) fYun('doorclosed', false, 0); }
function yunjinKickPrimero() { if (fYun != null) fYun('kick1', false, 0); }
function yunjinKickFinal() { if (fYun != null) fYun('kick2', true, 1); }

// ---- Callbacks de PlayState ----
function onBeatHit() { if (fBeat != null) fBeat(); }
function onUpdatePost(elapsed) { if (fUpdate != null) fUpdate(); }

function onEvent(name, value1, value2, time) {
	if (name == 'sserafimShow') {
		var v = _boolArr(value1, 'visible');
		if (v != null) visibilidadChicas(v);
	} else if (name == 'sserafimSing') {
		var s = _boolArr(value1, 'singing');
		if (s != null && fSing != null) {
			var t = [];
			for (i in 0...6) t.push(i < s.length ? s[i] == true : false);
			fSing(t[0], t[1], t[2], t[3], t[4], t[5]);
		}
	} else if (name == 'sserafimBeautiful') {
		if (value1 != null && value1.indexOf('{') >= 0) {
			isBeautiful = _boolField(value1, 'beautiful');
			if (game.gf != null) {
				game.gf.idleSuffix = isBeautiful ? '-beautiful' : '';
				game.gf.dance();
			}
		}
	}
}

function _cantar(noteData, noteType, isMiss) {
	if (fCantar == null) return;
	var baseAnim = SING_ANIMS[Std.int(Math.abs(noteData)) % 4];
	if (baseAnim == null) baseAnim = 'singLEFT';
	if (isMiss) baseAnim = baseAnim + 'miss';

	var animBf = baseAnim;
	if (noteType == 'sakura-joint') animBf = baseAnim + '-joint';
	else if (noteType == 'sakura-bf1') animBf = baseAnim + (isMiss ? '-bf2' : '-bf1');
	else if (noteType == 'sakura-bf2') animBf = baseAnim + '-bf2';

	var animGf = isBeautiful ? (baseAnim + '-beautiful') : baseAnim;
	var bfForce = (noteType != null && noteType.length >= 7 && noteType.substr(0, 7) == 'sakura-');
	fCantar(baseAnim, animBf, animGf, bfForce);
}

function goodNoteHit(note) {
	if (note.hitCausesMiss) return;
	_cantar(note.noteData, note.noteType, false);
}

function noteMiss(note) {
	if (note.ignoreNote) return;
	_cantar(note.noteData, note.noteType, true);
}

// Se crea todo aqui (despues de createPost del stage, para que frontStool y yunjinIntroSpr ya existan)
function onCreatePost() {
			var STD_MAP = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFFEEGGGEEEEHHDDDHHGGHHCCEEEEEDDDDDDDDDGGAAHHHHEEEEHHJJEEEEHHEEEHHGGCCJJHHGGEEEDDAAAAADEJJGEEHHLLHHGGGGHHEEGGHHEEEHHNNEEKKHHGGGKKJJJEEEHHHHHHHHHHHHGGGBBDDMMLLLJJJJKKKAAABBHHMMMLLLLHHHBBAJJEEEEEDDDAAAAAAMMLLKKEEHHHHOOGGGFFOOHHJJHHHHJJEEEEHHHHHHHHHLLLHHGGEEHHHHEEECCAAMMEEHHPPEEJJJNNNOOOOHHHHHHHAAAAAAHHEEEDDDBBCCJJEEEHHEEOOLLHHJJJEEHHHJJEEGGGGGGGGGGGGGGGGGEEKKLLFFEEMMLLEEKKGGGHHHJJJEEEEHHHHCCJJOOOOOOOOOHHHHHHHHHHHMMMMLLLHHHMMMLLLKKKHHHHLLLFFFJJJJHHMMLLLLCCJJEEEOOOOOOOHHHHHHHHHHHHEEECCCCMMLLLPPMMLLLPPMMLLCCEEEHHHMMLLLPPMMMLLPPOOOHHHEEEEHHOOOOHHHEEOOOCCHHHHHMMLLEEEEOOOOOOOOOODDDAAAAAAAAAAAAAAAAAAAAAAAADDDDHHHJJOOOCCCHHHHEEOOCCAALLLPPPMMLLPPMMLLLLJJEGGGGPPLLCCCJJEELLMMMMMMMMGGGFFFFFHHHEEKKHHHJJOOCCKKEEHHLLLLHHHEEEEENNOOHHHHEEKKPPPLLAACCEEEGGEEOOOHHHMMMLLLLLLPPPPPMMMLLLPPPCCCMMLLLOOOOOOOOOOOOOOOOOOOOAAAAAAAAAAAAAEECCJJEEHHJJJGGHHEEHHCCOOHHEEEGGGJJEEEEEEEEDDDHHHHCCEEHHMMLPPPOOOAACGGHHCCOOHHEEAACCEEEGGGJJEEEHHGGGGGGLLPPJJHHCCJJEEHHHJJEEEELLHHEECCCCJJEEEEEEHHHHOOHHHHHJJJJJJJJJCCCCOOHHHHEEHHHHHJJJJJJJJJEECCDDDDDDDDDAACCEEGGEEHHHMMLLPPPEEHHHHOOPPEENNNNJJCCAADDDDDDDDDAACCJJOOHHHHCCJJJGGGGEEHHCCPPLLOOPPMMEEHHHHJJJJJFFFFFHHHOOHHLLGGCCMMLLHHJJEEEEMMPPJJEECCEEEEEEEEHHHHHOOHHHHHJJJJJJJJJCCCCOOHHHHEEHHHHHJJJJJJJJJEECCDDDDDDDDEEEEEEEEEEJJJJEECDDDDDDEEEEEEEDDDDDDEEEEEHHDDDDDDDDEEEEEEEEEEJJJJEECCDDDDHHEEEEHHHEJJJJEECCAAADDDDDDDDDDEEEEEEEEEEJJJJEECDDDDDDEEEEEEEDDDDDDEEEEEHHDDDDDJJHHGGJJJJJJJJJCCCCCOOHHGGEEHHGGGJJJJJJJJJJJCCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADDDDEEHHDDOOHHEEHHGGOOHHHHEEOOGGHHCCEEOOOHHHHHHPPMMPPGGEENNOONNNNJJGGGGGJJHHGGOCCLLPPKKMMLLPPHHGGGDDDHHHHCCOONNLLHHGGEELLCCJJJJGGHHPPMMLLDDJJJEEEOOOOGGHHHHDDEECCOOKKLLLPPGGJJJJJJJJJFFFKKEEEEEOOOHHGGJJEEEEEEGGGGGGHHGGOOCCEEOOKKLLAACCOOHHEEOOOGGEEOOOOOOHHHHHHHHHHEEPPLLPPPPMMLLLPPEEEEEHHPPGGJJEEOOOHHHHHHHHHHHHHOOCCKKKJJJHHHHMMLLPPPLLEEEHHGGHHAAACCJJEEEEEEEEEEEEEEEEEPPPLLCOOGGHHGGJJJJJJEECCAAKKJJEEEEEEDDJJOOGGGGGGGGGGGGGGGGHHHGGGLLLPPPPJJEEEMMLLHHGGMMLLGGJJKKHHHEEOOCCJJLLLMMMLLLLPPGGGGGGDEEHHHMMLLHHKKJJEPPMMLLLPPJJEECCEEKKKMMLLLHHPPJJJOOOEEEDDDMMLLPPPPEEHHHEEEOOHHEEOOOCCJJEEEEEEEEEEEEOOGGGGGGGGGGGGGGAAAAAAAAAAAAAAHHHHGGJJEEEECCHHHGGEEOOOAAMMLLLPPEEOOGGEEDDDJJEEEGGMMLLCCJJEELLMMMMLLGGFFFFOOJJJJFFFEEEHHHJJEEGGEEEKKKEEJJHHHEEHHHHGGGGGGGJJJJJGGEEHHGGJJEEEEMMCCHHGGJJEEEEEECCCCMMLLLLLLCCCLLJJJJOOOOOOOOOOOOOOOOOOOOOOAAAAAAAAAAAAEECCJJEEHHJJJGGHHEEHHCCOOHHEEEGGGJJEEEEEEEEDDDHHHHCCEEHHMMLPPPOOOAACGGHHCCOOHHEEAACCEEEGGGJJEEEHHGGGGGGLLPPJJHHCCJJEEHHHJJEEEELLHHEECCCCJJEEEEEEHHHHOOHHHHHJJJJJJJJJCCCCOOHHHHEEHHHHHJJJJJJJJJEECCDDDDDDDDDAACCEEGGEEHHHMMLLPPPEEHHHHOOPPEENNNNJJCCAADDDDDDDDDAACCJJOOHHHHCCJJJGGGGEEHHCCPPLLOOPPMMEEHHHHJJJJJFFFFFHHHOOHHLLGGCCMMLLHHJJEEEEMMPPJJEECCEEEEEEEEHHHHHOOHHHHHJJJJJJJJJCCCCOOHHHHEEHHHHHJJJJJJJJJEECCDDDDDDDDEEEEEEEEEEJJJJEECDDDDDDEEEEEEEDDDDDDEEEEEHHDDDDDDDDEEEEEEEEEEJJJJEECCDDDDHHEEEEHHHEJJJJEECCAAADDDDDDDDDDEEEEEEEEEEJJJJEECDDDDDDEEEEEEEDDDDDDEEEEEHHDDDDDJJHHGGJJJJJJJJJCCCCCOOHHGGEEHHGGGJJJJJJJJJJJCCDDDDDDDDEEEEEEEEEEJJJJEECDDDDDDEEEEEEEDDDDDDEEEEEHHDDDDDDDDEEEEEEEEEEJJJJEECCDDDDHHEEEEHHHEJJJJEECCAAADDDDDDDDDDEEEEEEEEEEJJJJEECDDDDDDEEEEEEEDDDDDDEEEEEHHDDDDDJJHHGGJJJJJJJJJCCCCCOOHHGGEEHHGGGJJJJJJJJJJJCCEEOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO";
			var YUN_MAP = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGGFFHHHFFFFIIEEEIIHHIIDDFFFFFEEEEEEEEEHHBBIIIIFFFFIIKKFFFFIIFFFIIHHDDKKIIHHFFFEEBBBBBEFKKHFFIIMMIIHHHHIIFFHHIIFFFIIOOFFLLIIHHHLLKKKFFFIIIIIIIIIIIIHHHCCEENNMMMKKKKLLLBBBCCIINNNMMMMIIICCBKKFFFFFEEEBBBBBBNNMMLLFFIIIIPPHHHGGPPIIKKIIIIKKFFFFIIIIIIIIIMMMIIHHFFIIIIFFFDDBBNNFFIIQQFFKKKOOOPPPPIIIIIIIBBBBBBIIFFFEEECCDDKKFFFIIFFPPMMIIKKKFFIIIKKFFHHHHHHHHHHHHHHHHHFFLLMMGGFFNNMMFFLLHHHIIIKKKFFFFIIIIDDKKPPPPPPPPPIIIIIIIIIIINNNNMMMIIINNNMMMLLLIIIIMMMGGGKKKKIINNMMMMDDKKFFFPPPPPPPIIIIIIIIIIIIFFFDDDDNNMMMQQNNMMMQQNNMMDDFFFIIINNMMMQQNNNMMQQPPPIIIFFFFIIPPPPIIIFFPPPDDIIIIINNMMFFFFPPPPPPPPPPEEEBBBBBBBBBBBBBBBBBBBBBBBBEEEEIIIKKPPPDDDIIIIFFPPDDBBMMMQQQNNMMQQNNMMMMKKFHHHHQQMMDDDKKFFMMNNNNNNNNHHHGGGGGIIIFFLLIIIKKPPDDLLFFIIMMMMIIIFFFFFOOPPIIIIFFLLQQQMMBBDDFFFHHFFPPPIIINNNMMMMMMQQQQQNNNMMMQQQDDDNNMMMPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBBFFDDKKFFIIKKKHHIIFFIIDDPPIIFFFHHHKKFFFFFFFFEEEIIIIDDFFIINNMQQQPPPBBDHHIIDDPPIIFFBBDDFFFHHHKKFFFIIHHHHHHMMQQKKIIDDKKFFIIIKKFFFFMMIIFFDDDDKKFFFFFFIIIIPPIIIIIKKKKKKKKKDDDDPPIIIIFFIIIIIKKKKKKKKKFFDDEEEEEEEEEBBDDFFHHFFIIINNMMQQQFFIIIIPPQQFFOOOOKKDDBBEEEEEEEEEBBDDKKPPIIIIDDKKKHHHHFFIIDDQQMMPPQQNNFFIIIIKKKKKGGGGGIIIPPIIMMHHDDNNMMIIKKFFFFNNQQKKFFDDFFFFFFFFIIIIIPPIIIIIKKKKKKKKKDDDDPPIIIIFFIIIIIKKKKKKKKKFFDDEEEEEEEEFFFFFFFFFFKKKKFFDEEEEEEFFFFFFFEEEEEEFFFFFIIEEEEEEEEFFFFFFFFFFKKKKFFDDEEEEIIFFFFIIIFKKKKFFDDBBBEEEEEEEEEEFFFFFFFFFFKKKKFFDEEEEEEFFFFFFFEEEEEEFFFFFIIEEEEEKKIIHHKKKKKKKKKDDDDDPPIIHHFFIIHHHKKKKKKKKKKKDDBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBEEEEFFIIEEPPIIFFIIHHPPIIIIFFPPHHIIDDFFPPPIIIIIIQQNNQQHHFFOOPPOOOOKKHHHHHKKIIHHPDDMMQQLLNNMMQQIIHHHEEEIIIIDDPPOOMMIIHHFFMMDDKKKKHHIIQQNNMMEEKKKFFFPPPPHHIIIIEEFFDDPPLLMMMQQHHKKKKKKKKKGGGLLFFFFFPPPIIHHKKFFFFFFHHHHHHIIHHPPDDFFPPLLMMBBDDPPIIFFPPPHHFFPPPPPPIIIIIIIIIIFFQQMMQQQQNNMMMQQFFFFFIIQQHHKKFFPPPIIIIIIIIIIIIIPPDDLLLKKKIIIINNMMQQQMMFFFIIHHIIBBBDDKKFFFFFFFFFFFFFFFFFQQQMMDPPHHIIHHKKKKKKFFDDBBLLKKFFFFFFEEKKPPHHHHHHHHHHHHHHHHIIIHHHMMMQQQQKKFFFNNMMIIHHNNMMHHKKLLIIIFFPPDDKKMMMNNNMMMMQQHHHHHHEFFIIINNMMIILLKKFQQNNMMMQQKKFFDDFFLLLNNMMMIIQQKKKPPPFFFEEENNMMQQQQFFIIIFFFPPIIFFPPPDDKKFFFFFFFFFFFFPPHHHHHHHHHHHHHHBBBBBBBBBBBBBBIIIIHHKKFFFFDDIIIHHFFPPPBBNNMMMQQFFPPHHFFEEEKKFFFHHNNMMDDKKFFMMNNNNMMHHGGGGPPKKKKGGGFFFIIIKKFFHHFFFLLLFFKKIIIFFIIIIHHHHHHHKKKKKHHFFIIHHKKFFFFNNDDIIHHKKFFFFFFDDDDNNMMMMMMDDDMMKKKKPPPPPPPPPPPPPPPPPPPPPPBBBBBBBBBBBBFFDDKKFFIIKKKHHIIFFIIDDPPIIFFFHHHKKFFFFFFFFEEEIIIIDDFFIINNMQQQPPPBBDHHIIDDPPIIFFBBDDFFFHHHKKFFFIIHHHHHHMMQQKKIIDDKKFFIIIKKFFFFMMIIFFDDDDKKFFFFFFIIIIPPIIIIIKKKKKKKKKDDDDPPIIIIFFIIIIIKKKKKKKKKFFDDEEEEEEEEEBBDDFFHHFFIIINNMMQQQFFIIIIPPQQFFOOOOKKDDBBEEEEEEEEEBBDDKKPPIIIIDDKKKHHHHFFIIDDQQMMPPQQNNFFIIIIKKKKKGGGGGIIIPPIIMMHHDDNNMMIIKKFFFFNNQQKKFFDDFFFFFFFFIIIIIPPIIIIIKKKKKKKKKDDDDPPIIIIFFIIIIIKKKKKKKKKFFDDEEEEEEEEFFFFFFFFFFKKKKFFDEEEEEEFFFFFFFEEEEEEFFFFFIIEEEEEEEEFFFFFFFFFFKKKKFFDDEEEEIIFFFFIIIFKKKKFFDDBBBEEEEEEEEEEFFFFFFFFFFKKKKFFDEEEEEEFFFFFFFEEEEEEFFFFFIIEEEEEKKIIHHKKKKKKKKKDDDDDPPIIHHFFIIHHHKKKKKKKKKKKDDEEEEEEEEFFFFFFFFFFKKKKFFDEEEEEEFFFFFFFEEEEEEFFFFFIIEEEEEEEEFFFFFFFFFFKKKKFFDDEEEEIIFFFFIIIFKKKKFFDDBBBEEEEEEEEEEFFFFFFFFFFKKKKFFDEEEEEEFFFFFFFEEEEEEFFFFFIIEEEEEKKIIHHKKKKKKKKKDDDDDPPIIHHFFIIHHHKKKKKKKKKKKDDFFPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP";
			var stdLen = STD_MAP.length;
			var yunLen = YUN_MAP.length;
			var STD_FRAMES = [];
			for (i in 0...stdLen) STD_FRAMES.push(STD_MAP.charCodeAt(i) - 65);
			var YUN_FRAMES = [];
			for (i in 0...yunLen) YUN_FRAMES.push(YUN_MAP.charCodeAt(i) - 65);

			var chSh = ClientPrefs.data.shaders ? game.variables.get('sserCharShader') : null;
			if (game.boyfriend != null && game.boyfriend.isAnimateAtlas && game.boyfriend.atlas != null && game.boyfriend.atlas.width <= 0) {
				game.boyfriend.atlas.width = 590.84;
				game.boyfriend.atlas.height = 683.15;
			}

			// Limpia capas Clipper en personajes que la tienen (Yunjin y GF) estilo Sserafim.hideClipperLayers
			var ocultarClippers = function(spr) {
				if (spr == null || spr.anim == null) return;
				if (spr.anim.metadata != null) {
					spr.anim.metadata.skipFilters = true;
					spr.anim.metadata.showHiddenLayers = false;
				}
				var clearSym = function(sym) {
					if (sym == null || sym.timeline == null) return;
					var normalType = null;
					for (layer in sym.timeline.getList()) {
						if (layer == null) continue;
						var lt = (layer.type != null) ? Type.enumConstructor(layer.type) : '';
						if (lt == 'Clipper') {
							layer._correctClip = true;
							layer.visible = false;
						} else if (lt == 'Clipped' || layer._clipper != null) {
							if (normalType == null && layer.type != null)
								normalType = Type.createEnum(Type.getEnum(layer.type), 'Normal');
							layer._clipper = null;
							if (normalType != null) layer.type = normalType;
						}
					}
				};
				if (spr.anim.symbolDictionary != null) {
					for (sym in spr.anim.symbolDictionary) clearSym(sym);
				}
				clearSym(spr.anim.curSymbol);
			};

			if (game.gf != null && game.gf.isAnimateAtlas) ocultarClippers(game.gf.atlas);

			var makeLip = function(yunVar, alphaVal, flipped) {
				var w = 47;
				var h = yunVar ? 40 : 36;
				var bw = 46.6632;
				var bh = yunVar ? 39.6484 : 35.2032;
				var lip = new FlxSprite();
				var g = Paths.image(yunVar ? 'sserafim-lipsync-yunjin-strip' : 'sserafim-lipsync-strip');
				if (g != null) lip.loadGraphic(g, true, w, h);
				else lip.makeGraphic(w, h, 0x00000000);
				lip.origin.set(bw * 0.5, bh * 0.5);
				lip.flipX = flipped;
				lip.antialiasing = ClientPrefs.data.antialiasing;
				lip.alpha = alphaVal;
				lip.visible = false;
				if (chSh != null) lip.shader = chSh;
				return lip;
			};

			var makeFrontAtlas = function(srcChar, imgPath) {
				if (srcChar == null || !srcChar.isAnimateAtlas) return null;
				var fr = new FlxAnimate(srcChar.x, srcChar.y);
				fr.showPivot = false;
				Paths.loadAnimateAtlas(fr, imgPath);
				for (anim in srcChar.animationsArray) {
					if (anim.indices != null && anim.indices.length > 0)
						fr.anim.addBySymbolIndices(anim.anim, anim.name, anim.indices, anim.fps, anim.loop);
					else
						fr.anim.addBySymbol(anim.anim, anim.name, anim.fps, anim.loop);
				}
				ocultarClippers(fr);
				fr.active = false;
				fr.visible = false;
				if (chSh != null) fr.shader = chSh;
				return fr;
			};

			var yunjin = new Character(0, 0, 'sserafim-yunjin', false);
			yunjin.setPosition(-621 + yunjin.positionArray[0], 154 + yunjin.positionArray[1]);
			yunjin.scrollFactor.set(0.95, 0.95);
			yunjin.danceEveryNumBeats = 0;
			yunjin.playAnim('doorclosed', true);
			if (chSh != null) yunjin.shader = chSh;
			if (yunjin.isAnimateAtlas) ocultarClippers(yunjin.atlas);
			game.variables.set('yunjin', yunjin);

			var chaewon = new Character(0, 0, 'sserafim-chaewon', false);
			chaewon.setPosition(687 + chaewon.positionArray[0], 98 + chaewon.positionArray[1]);
			chaewon.scrollFactor.set(0.95, 0.95);
			if (chSh != null) chaewon.shader = chSh;
			game.variables.set('chaewon', chaewon);

			var eunchae = new Character(0, 0, 'sserafim-eunchae', false);
			eunchae.setPosition(770 + eunchae.positionArray[0], 675 + eunchae.positionArray[1]);
			eunchae.scrollFactor.set(0.97, 0.97);
			if (chSh != null) eunchae.shader = chSh;
			game.variables.set('eunchae', eunchae);

			var lipDad = makeLip(false, 1.0, true);
			var lipBf = makeLip(false, 1.0, true);
			var lipYunjin = makeLip(true, 1.0, false);
			var lipChaewon = makeLip(false, 1.0, false);
			var lipEunchae = makeLip(false, 1.0, false);

			// Kazuha nunca tiene capas por encima de la boca (layerIdx == 0), evitamos clonar su atlas
			var frontDad = null;
			var frontBf = makeFrontAtlas(game.boyfriend, 'characters/sserafim/sakura');
			var frontYunjin = makeFrontAtlas(yunjin, 'characters/sserafim/yunjin');
			var frontChaewon = makeFrontAtlas(chaewon, 'characters/sserafim/chaewon');
			var frontEunchae = makeFrontAtlas(eunchae, 'characters/sserafim/eunchae');

			if (chSh != null) {
				var yi = game.getLuaObject('yunjinIntroSpr');
				if (yi != null) yi.shader = chSh;
			}

			// Orden visual: dad->lip, bf->lip->front, yunjinIntro/yunjin->lip->front, chaewon, eunchae antes de frontStool
			var insertarDespues = function(anchor, obj) {
				if (anchor == null || obj == null) return anchor;
				var i = game.members.indexOf(anchor);
				if (i >= 0) game.insert(i + 1, obj);
				else game.add(obj);
				return obj;
			};
			insertarDespues(game.dadGroup, lipDad);

			var p = insertarDespues(game.boyfriendGroup, lipBf);
			insertarDespues(p, frontBf);

			var stoolObj = game.getLuaObject('frontStool');
			var insertBeforeStool = function(obj) {
				if (obj == null) return;
				var sIdx = (stoolObj != null) ? game.members.indexOf(stoolObj) : -1;
				if (sIdx >= 0) game.insert(sIdx, obj);
				else game.add(obj);
			};

			var yiSpr = game.getLuaObject('yunjinIntroSpr');
			if (yiSpr != null) {
				game.remove(yiSpr, true);
				insertBeforeStool(yiSpr);
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

			game.variables.set('lipDad', lipDad);
			game.variables.set('lipBf', lipBf);
			game.variables.set('lipYunjin', lipYunjin);
			game.variables.set('lipChaewon', lipChaewon);
			game.variables.set('lipEunchae', lipEunchae);

			game.variables.set('frontBf', frontBf);
			game.variables.set('frontYunjin', frontYunjin);
			game.variables.set('frontChaewon', frontChaewon);
			game.variables.set('frontEunchae', frontEunchae);

			for (obj in [game.dad, game.boyfriend, yunjin, chaewon, eunchae]) {
				if (obj != null && obj.isAnimateAtlas && obj.atlas != null && obj.atlas.anim != null && obj.atlas.anim.metadata != null) {
					obj.atlas.anim.metadata.showHiddenLayers = false;
				}
			}

			var cfgs = [
				{idx: 1, c: game.dad, lip: lipDad, fr: frontDad, sym: 'mouth default', yun: false, cur: [5, 4, -13],
					prevSym: null, prevFrSym: null, hiddenC: [], hiddenFr: [], lastAnim: '', lastFr: -999, wasFrontVis: false, lastLipFrame: -1,
					lastKeyAnim: '', lastKeyFr: -999, lastEntry: null, lastLipX: -999999.0, lastLipY: -999999.0, lastLipAng: -999999.0,
					lastFrX: -999999.0, lastFrY: -999999.0, lastFrA: -1.0, lastFrAng: -999999.0, lastFrFlipX: false, lastFrFlipY: false,
					offs: ['idle' => [5,4,-13], 'singUP' => [7,2,-14], 'singRIGHT' => [7,2,-13], 'singDOWN' => [4,6,-12], 'singLEFT' => [5,4,-14],
						'singUPmiss' => [7,2,-14], 'singRIGHTmiss' => [7,2,-13], 'singDOWNmiss' => [4,6,-12], 'singLEFTmiss' => [5,4,-14]]},
				{idx: 4, c: game.boyfriend, lip: lipBf, fr: frontBf, sym: 'mouth edit', yun: false, cur: [7, 2, -14],
					prevSym: null, prevFrSym: null, hiddenC: [], hiddenFr: [], lastAnim: '', lastFr: -999, wasFrontVis: false, lastLipFrame: -1,
					lastKeyAnim: '', lastKeyFr: -999, lastEntry: null, lastLipX: -999999.0, lastLipY: -999999.0, lastLipAng: -999999.0,
					lastFrX: -999999.0, lastFrY: -999999.0, lastFrA: -1.0, lastFrAng: -999999.0, lastFrFlipX: false, lastFrFlipY: false,
					offs: ['idle' => [7,2,-14], 'singUP' => [8,1,-15], 'singRIGHT' => [7,2,-15], 'singDOWN' => [6,3,-15], 'singLEFT' => [7,2,-14],
						'singUP-joint' => [10,-1,-14], 'singRIGHT-joint' => [6,3,-15], 'singDOWN-joint' => [5,5,-15], 'singLEFT-joint' => [7,2,-16],
						'singUPmiss' => [8,1,-15], 'singRIGHTmiss' => [7,2,-15], 'singDOWNmiss' => [6,3,-15], 'singLEFTmiss' => [7,2,-14],
						'singUPmiss-joint' => [10,-1,-14], 'singRIGHTmiss-joint' => [6,3,-15], 'singDOWNmiss-joint' => [5,5,-15], 'singLEFTmiss-joint' => [7,2,-16],
						'singUP-bf1' => [7,2,-14], 'singRIGHT-bf1' => [7,2,-14], 'singDOWN-bf1' => [7,2,-14], 'singLEFT-bf1' => [7,2,-14],
						'singUP-bf2' => [7,2,-14], 'singRIGHT-bf2' => [7,2,-14], 'singDOWN-bf2' => [7,2,-14], 'singLEFT-bf2' => [7,2,-14],
						'singUPmiss-bf2' => [7,2,-14], 'singRIGHTmiss-bf2' => [7,2,-14], 'singDOWNmiss-bf2' => [7,2,-14], 'singLEFTmiss-bf2' => [7,2,-14]]},
				{idx: 0, c: yunjin, lip: lipYunjin, fr: frontYunjin, sym: 'mouth yunjin', yun: true, cur: [8, 6, 23],
					prevSym: null, prevFrSym: null, hiddenC: [], hiddenFr: [], lastAnim: '', lastFr: -999, wasFrontVis: false, lastLipFrame: -1,
					lastKeyAnim: '', lastKeyFr: -999, lastEntry: null, lastLipX: -999999.0, lastLipY: -999999.0, lastLipAng: -999999.0,
					lastFrX: -999999.0, lastFrY: -999999.0, lastFrA: -1.0, lastFrAng: -999999.0, lastFrFlipX: false, lastFrFlipY: false,
					offs: ['idle' => [8,6,23], 'singUP' => [6,8,22], 'singRIGHT' => [6,8,23], 'singDOWN' => [8,6,23], 'singLEFT' => [6,8,23],
						'singUPmiss' => [6,8,22], 'singRIGHTmiss' => [6,8,23], 'singDOWNmiss' => [8,6,23], 'singLEFTmiss' => [6,8,23]]},
				{idx: 2, c: chaewon, lip: lipChaewon, fr: frontChaewon, sym: 'mouth default', yun: false, cur: [41, 3, -166],
					prevSym: null, prevFrSym: null, hiddenC: [], hiddenFr: [], lastAnim: '', lastFr: -999, wasFrontVis: false, lastLipFrame: -1,
					lastKeyAnim: '', lastKeyFr: -999, lastEntry: null, lastLipX: -999999.0, lastLipY: -999999.0, lastLipAng: -999999.0,
					lastFrX: -999999.0, lastFrY: -999999.0, lastFrA: -1.0, lastFrAng: -999999.0, lastFrFlipX: false, lastFrFlipY: false,
					offs: ['idle' => [41,3,-166], 'singUP' => [38,0,-168], 'singRIGHT' => [39,1,-165], 'singDOWN' => [41,3,-167], 'singLEFT' => [40,2,-165],
						'singUPmiss' => [38,0,-168], 'singRIGHTmiss' => [39,1,-165], 'singDOWNmiss' => [41,3,-167], 'singLEFTmiss' => [40,2,-165]]},
				{idx: 3, c: eunchae, lip: lipEunchae, fr: frontEunchae, sym: 'mouth default', yun: false, cur: [43, 6, -168],
					prevSym: null, prevFrSym: null, hiddenC: [], hiddenFr: [], lastAnim: '', lastFr: -999, wasFrontVis: false, lastLipFrame: -1,
					lastKeyAnim: '', lastKeyFr: -999, lastEntry: null, lastLipX: -999999.0, lastLipY: -999999.0, lastLipAng: -999999.0,
					lastFrX: -999999.0, lastFrY: -999999.0, lastFrA: -1.0, lastFrAng: -999999.0, lastFrFlipX: false, lastFrFlipY: false,
					offs: ['idle' => [43,6,-168], 'singUP' => [45,10,-166], 'singRIGHT' => [42,5,-166], 'singDOWN' => [41,3,-168], 'singLEFT' => [43,6,-169],
						'singUPmiss' => [45,10,-166], 'singRIGHTmiss' => [42,5,-166], 'singDOWNmiss' => [41,3,-168], 'singLEFTmiss' => [43,6,-169]]}
			];
			game.variables.set('yunjinVisibleEstado', true);
			var _yunVisWant = true;
			var sArr = [false, false, false, false, false, false];
			game.variables.set('sserafimIsSinging', sArr);
			var _extras = [yunjin, chaewon, eunchae];
			var _chars = [yunjin, game.dad, chaewon, eunchae, game.boyfriend, game.gf];
			var _lastYiX = -999999.0;
			var _lastYiY = -999999.0;

			function _sserSetGirlVis(v0, v1, v2, v3, v4) {
				_yunVisWant = v0;
				game.variables.set('yunjinVisibleEstado', v0);
				if (yunjin != null) yunjin.visible = v0;
				if (yiSpr != null && !v0) yiSpr.visible = false;
				if (game.dad != null) game.dad.visible = v1;
				if (chaewon != null) chaewon.visible = v2;
				if (eunchae != null) eunchae.visible = v3;
				if (game.boyfriend != null) game.boyfriend.visible = v4;
			}

			function _sserYunjinAnim(animName, isSpecial, beats) {
				if (yunjin == null) return;
				yunjin.danceEveryNumBeats = beats;
				yunjin.playAnim(animName, true);
				yunjin.specialAnim = isSpecial;
			}

			function _sserSetSinging(s0, s1, s2, s3, s4, s5) {
				sArr[0] = s0; sArr[1] = s1; sArr[2] = s2; sArr[3] = s3; sArr[4] = s4; sArr[5] = s5;
			}

			function _sserBeatChicas() {
				for (extra in _extras) {
					if (extra == null || extra.isAnimationNull()) continue;
					var curA = extra.getAnimationName();
					if (!StringTools.startsWith(curA, 'sing') && !extra.specialAnim && !extra.stunned
						&& extra.danceEveryNumBeats > 0 && game.curBeat % extra.danceEveryNumBeats == 0) {
						extra.dance();
					}
				}
			}

			function _sserCantar(baseAnim, animBf, animGf, bfForce) {
				for (i in 0...6) {
					var c = _chars[i];
					if (c == null) continue;
					var active = sArr[i] || (i == 4 && bfForce);
					if (!active) continue;
					var targetAnim = (i == 4) ? animBf : ((i == 5) ? animGf : baseAnim);
					if (c.hasAnimation(targetAnim)) {
						c.specialAnim = false;
						c.playAnim(targetAnim, true);
						c.holdTimer = 0;
					} else if (c.hasAnimation(baseAnim)) {
						c.specialAnim = false;
						c.playAnim(baseAnim, true);
						c.holdTimer = 0;
					}
				}
			}

			// Pool pre-alocado + cache por (personaje, animacion, frame) = CERO asignaciones por frame
			var _matPool = [];
			for (_i in 0...16) _matPool.push(new FlxMatrix());
			var _mouthCache = new StringMap();
			var _restaurarCapas = function(cfg) {
				if (cfg.hiddenC != null && cfg.hiddenC.length > 0) {
					for (l in cfg.hiddenC) if (l != null) l.visible = true;
					cfg.hiddenC.resize(0);
				}
				if (cfg.hiddenFr != null && cfg.hiddenFr.length > 0) {
					for (l in cfg.hiddenFr) if (l != null) l.visible = true;
					cfg.hiddenFr.resize(0);
				}
				cfg.prevSym = null;
				cfg.prevFrSym = null;
			};
			var _findMouth = null;
			_findMouth = function(anim, instance, parentMat, frameOffset, targetSubstr, outMat, depth, outCtx) {
				if (anim == null || instance == null || depth > 12 || instance.symbol == null) return false;
				var sym = anim.symbolDictionary.get(instance.symbol.name);
				if (sym == null) return false;

				var curMat = _matPool[depth];
				curMat.copyFrom(instance.matrix);
				curMat.translate(instance.x, instance.y);
				curMat.concat(parentMat);

				if (instance.symbol.name != null && instance.symbol.name.toLowerCase().indexOf(targetSubstr) >= 0) {
					outMat.copyFrom(curMat);
					return true;
				}

				var symLen = sym.length > 0 ? sym.length : 1;
				var loopName = (instance.symbol.loop != null) ? Std.string(instance.symbol.loop) : '';
				var typeName = (instance.symbol.type != null) ? Std.string(instance.symbol.type) : '';
				var curFF = frameOffset;
				if (depth > 0) {
					if (loopName == 'Loop') curFF = (frameOffset + instance.symbol.firstFrame) % symLen;
					else if (loopName == 'PlayOnce') curFF = Std.int(FlxMath.bound(frameOffset + instance.symbol.firstFrame, 0, symLen - 1));
					else curFF = instance.symbol.firstFrame;
				}
				if (typeName == 'MovieClip') curFF = 0;

				var layers = sym.timeline.getList();
				for (li in 0...layers.length) {
					var layer = layers[li];
					if (layer == null || !layer.visible) continue;
					var kf = layer.get(curFF);
					if (kf == null) continue;
					var relFrame = curFF - kf.index;
					if (relFrame < 0) relFrame = 0;
					for (el in kf.getList()) {
						if (el != null && el.symbol != null) {
							if (_findMouth(anim, el, curMat, relFrame, targetSubstr, outMat, depth + 1, outCtx)) {
								if (outCtx != null && outCtx.poseSymName == null) {
									outCtx.poseSymName = sym.name;
									outCtx.layerIdx = li;
								}
								return true;
							}
						}
					}
				}
				return false;
			};

			var _identMat = new FlxMatrix();
			var _resMat = new FlxMatrix();

			function _sserUpdateLipAndFront() {
				var inCut = game.inCutscene;
				var rawT = Math.floor((Conductor.songPosition / 1000.0) * 24.0) - 1;
				var idxStd = (rawT < 0) ? 0 : ((rawT >= stdLen) ? stdLen - 1 : rawT);
				var idxYun = (rawT < 0) ? 0 : ((rawT >= yunLen) ? yunLen - 1 : rawT);
				var stdFr = STD_FRAMES[idxStd];
				var yunFr = YUN_FRAMES[idxYun];

				// Swap de Yunjin en puerta por yunjinIntro pre-bakeado
				var yunjinUsandoIntro = false;
				if (yunjin != null && yiSpr != null && _yunVisWant && !yunjin.isAnimationNull()) {
					var curA = yunjin.getAnimationName();
					if (curA == 'doorclosed' || curA == 'kick1' || curA == 'kick2') {
						yunjinUsandoIntro = true;
						var cf = (yunjin.isAnimateAtlas && yunjin.atlas != null && yunjin.atlas.anim != null && yunjin.atlas.anim.curInstance != null && yunjin.atlas.anim.curInstance.symbol != null)
							? yunjin.atlas.anim.curInstance.symbol._curFrame : 0;
						if (yiSpr.animation.curAnim == null || yiSpr.animation.curAnim.name != curA) {
							yiSpr.animation.play(curA, true, false, cf);
							yiSpr.animation.pause();
						} else if (cf >= 0 && cf < yiSpr.animation.curAnim.numFrames && yiSpr.animation.curAnim.curFrame != cf)
							yiSpr.animation.curAnim.curFrame = cf;
						var yx = yunjin.x - yunjin.offset.x - 7.0;
						var yy = yunjin.y - yunjin.offset.y + 154.0;
						if (yx != _lastYiX || yy != _lastYiY) {
							yiSpr.setPosition(yx, yy);
							_lastYiX = yx; _lastYiY = yy;
						}
						if (yiSpr.alpha != yunjin.alpha) yiSpr.alpha = yunjin.alpha;
						if (yiSpr.shader != yunjin.shader) yiSpr.shader = yunjin.shader;
						if (yiSpr.cameras != yunjin.cameras) yiSpr.cameras = yunjin.cameras;
						if (yiSpr.visible != !inCut) yiSpr.visible = !inCut;
						if (yunjin.visible) yunjin.visible = false;
					} else {
						if (yiSpr.visible) yiSpr.visible = false;
						if (!yunjin.visible) yunjin.visible = true;
					}
				} else {
					if (yiSpr != null && yiSpr.visible) yiSpr.visible = false;
					if (yunjin != null && yunjin.visible != _yunVisWant) yunjin.visible = _yunVisWant;
				}

				for (cfg in cfgs) {
					var c = cfg.c;
					var lip = cfg.lip;
					var fr = cfg.fr;

					var charVis = (!inCut && c != null && c.exists && c.visible && c.alpha > 0.01 && c.isAnimateAtlas
						&& c.atlas != null && c.atlas.anim != null && c.atlas.anim.curInstance != null && c.atlas.anim.curInstance.symbol != null);

					if (!charVis || (cfg.idx == 0 && yunjinUsandoIntro)) {
						if (cfg.wasFrontVis || cfg.hiddenC.length > 0 || cfg.hiddenFr.length > 0) _restaurarCapas(cfg);
						if (lip != null && lip.visible) lip.visible = false;
						if (fr != null && fr.visible) fr.visible = false;
						cfg.wasFrontVis = false;
						continue;
					}

					var inst = c.atlas.anim.curInstance;
					// CRITICO: usar inst.symbol._curFrame (frame exacto que FlxAnimate.draw() dibuja), no anim.curFrame
					var curFr = inst.symbol._curFrame;
					var animName = c.getAnimationName();
					if (animName == null) animName = '';

					var entry = (cfg.lastEntry != null && cfg.lastKeyFr == curFr && cfg.lastKeyAnim == animName) ? cfg.lastEntry : null;
					if (entry == null) {
						var cacheKey = cfg.idx + '|' + animName + '|' + curFr;
						entry = _mouthCache.get(cacheKey);
						if (entry == null) {
							// Restaurar capas ocultas de frames previos ANTES de recorrer el timeline
							_restaurarCapas(cfg);
							var ctx = {poseSymName: null, layerIdx: -1};
							var found = _findMouth(c.atlas.anim, inst, _identMat, curFr, cfg.sym, _resMat, 0, ctx);
							if (!found && cfg.idx == 4) {
								ctx.poseSymName = null;
								ctx.layerIdx = -1;
								found = _findMouth(c.atlas.anim, inst, _identMat, curFr, 'mouth default', _resMat, 0, ctx);
							}
							entry = {
								found: found,
								rawTx: _resMat.tx,
								rawTy: _resMat.ty,
								rawA: _resMat.a,
								rawB: _resMat.b,
								poseSymName: ctx.poseSymName,
								layerIdx: ctx.layerIdx
							};
							_mouthCache.set(cacheKey, entry);
						}
						cfg.lastKeyAnim = animName;
						cfg.lastKeyFr = curFr;
						cfg.lastEntry = entry;
					}

					if (!entry.found) {
						if (cfg.wasFrontVis || cfg.hiddenC.length > 0 || cfg.hiddenFr.length > 0) _restaurarCapas(cfg);
						if (lip != null && lip.visible) lip.visible = false;
						if (fr != null && fr.visible) fr.visible = false;
						cfg.wasFrontVis = false;
						continue;
					}

					var tx = entry.rawTx;
					if (c.flipX) {
						var atlasW = (c.atlas.width > 0) ? c.atlas.width : 590.84;
						tx = atlasW - tx;
					}

					if (cfg.offs.exists(animName)) cfg.cur = cfg.offs.get(animName);

					var worldX = c.x - c.offset.x + tx;
					var worldY = c.y - c.offset.y + entry.rawTy;
					var headDeg = Math.atan2(entry.rawB, c.flipX ? -entry.rawA : entry.rawA) * 180.0 / Math.PI;
					var singing = sArr[cfg.idx];

					if (lip != null) {
						if (!lip.visible) lip.visible = true;
						if (lip.scrollFactor.x != c.scrollFactor.x || lip.scrollFactor.y != c.scrollFactor.y)
							lip.scrollFactor.set(c.scrollFactor.x, c.scrollFactor.y);
						if (lip.shader != c.shader) lip.shader = c.shader;
						if (lip.cameras != c.cameras) lip.cameras = c.cameras;
						var targetLipFr = singing ? (cfg.yun ? yunFr : stdFr) : 0;
						if (cfg.lastLipFrame != targetLipFr) {
							lip.animation.frameIndex = targetLipFr;
							cfg.lastLipFrame = targetLipFr;
						}
						var targetAng = headDeg + cfg.cur[2];
						if (cfg.lastLipAng != targetAng) {
							lip.angle = targetAng;
							cfg.lastLipAng = targetAng;
						}
						var lx = worldX - cfg.cur[0];
						var ly = worldY - cfg.cur[1];
						if (cfg.lastLipX != lx || cfg.lastLipY != ly) {
							lip.setPosition(lx, ly);
							cfg.lastLipX = lx;
							cfg.lastLipY = ly;
						}
					}

					var poseSym = (entry.poseSymName != null) ? c.atlas.anim.symbolDictionary.get(entry.poseSymName) : null;
					if (fr != null && poseSym != null && entry.layerIdx > 0 && poseSym.timeline != null) {
						var layers = poseSym.timeline.getList();
						if (entry.layerIdx < layers.length) {
							var frSym = fr.anim.symbolDictionary.get(poseSym.name);
							var poseChanged = (!cfg.wasFrontVis || cfg.lastAnim != animName || cfg.lastFr != curFr || cfg.prevSym != poseSym);
							if (poseChanged) {
								_restaurarCapas(cfg);
								if (animName != '') {
									if (!cfg.wasFrontVis || cfg.lastAnim != animName) {
										fr.anim.play(animName, true, false, curFr);
									} else if (cfg.lastFr != curFr) {
										fr.anim.curFrame = curFr;
										if (fr.anim.curInstance != null && fr.anim.curInstance.symbol != null)
											fr.anim.curInstance.symbol._curFrame = curFr;
									}
									fr.anim.pause();
									fr.anim.update(0);
								}

								for (i in 0...entry.layerIdx) {
									if (layers[i] != null && layers[i].visible) {
										layers[i].visible = false;
										cfg.hiddenC.push(layers[i]);
									}
								}
								cfg.prevSym = poseSym;

								if (frSym != null && frSym.timeline != null) {
									var fls = frSym.timeline.getList();
									for (i in entry.layerIdx...fls.length) {
										if (fls[i] != null && fls[i].visible) {
											fls[i].visible = false;
											cfg.hiddenFr.push(fls[i]);
										}
									}
									cfg.prevFrSym = frSym;
								}
								cfg.lastAnim = animName;
								cfg.lastFr = curFr;
							}

							if (fr.cameras != c.cameras) fr.cameras = c.cameras;
							if (fr.scrollFactor.x != c.scrollFactor.x || fr.scrollFactor.y != c.scrollFactor.y)
								fr.scrollFactor.set(c.scrollFactor.x, c.scrollFactor.y);
							if (fr.scale.x != c.scale.x || fr.scale.y != c.scale.y)
								fr.scale.set(c.scale.x, c.scale.y);
							if (fr.offset.x != c.offset.x || fr.offset.y != c.offset.y)
								fr.offset.set(c.offset.x, c.offset.y);
							if (fr.origin.x != c.origin.x || fr.origin.y != c.origin.y)
								fr.origin.set(c.origin.x, c.origin.y);
							if (cfg.lastFrX != c.x || cfg.lastFrY != c.y) {
								fr.setPosition(c.x, c.y);
								cfg.lastFrX = c.x; cfg.lastFrY = c.y;
							}
							if (cfg.lastFrAng != c.angle) { fr.angle = c.angle; cfg.lastFrAng = c.angle; }
							if (cfg.lastFrA != c.alpha) { fr.alpha = c.alpha; cfg.lastFrA = c.alpha; }
							if (cfg.lastFrFlipX != c.flipX) { fr.flipX = c.flipX; cfg.lastFrFlipX = c.flipX; }
							if (cfg.lastFrFlipY != c.flipY) { fr.flipY = c.flipY; cfg.lastFrFlipY = c.flipY; }
							if (fr.shader != c.shader) fr.shader = c.shader;
							if (fr.antialiasing != c.antialiasing) fr.antialiasing = c.antialiasing;
							if (fr.color != c.color) fr.color = c.color;
							// CRITICO para Sakura (flipX=true): FlxAnimate.draw() usa fr.width como pivote horizontal
							if (c.flipX) {
								var aw = (c.atlas.width > 0) ? c.atlas.width : 590.84;
								if (fr.width != aw) fr.width = aw;
							}
							if (!fr.visible) fr.visible = true;
							cfg.wasFrontVis = true;
						} else {
							if (cfg.wasFrontVis || cfg.hiddenC.length > 0 || cfg.hiddenFr.length > 0) _restaurarCapas(cfg);
							if (fr.visible) fr.visible = false;
							cfg.wasFrontVis = false;
						}
					} else {
						if (cfg.wasFrontVis || cfg.hiddenC.length > 0 || cfg.hiddenFr.length > 0) _restaurarCapas(cfg);
						if (fr != null && fr.visible) fr.visible = false;
						cfg.wasFrontVis = false;
					}
				}
			}

		fUpdate = _sserUpdateLipAndFront;
		fVis = _sserSetGirlVis;
		fYun = _sserYunjinAnim;
		fSing = _sserSetSinging;
		fBeat = _sserBeatChicas;
		fCantar = _sserCantar;

		// Visibilidad inicial (la pide el stage con aplicarCutscene antes de que existiera el script)
		var pv = game.variables.get('sserGirlsVis');
		if (pv == null) pv = [true, false, false, false, false];
		fVis(pv[0] == true, pv[1] == true, pv[2] == true, pv[3] == true, pv[4] == true);
}
