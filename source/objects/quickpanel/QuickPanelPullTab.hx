package objects.quickpanel;

import backend.Paths;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flxanimate._PsychFlxAnimate.FlxAnimate;
import objects.quickpanel.QuickPanelGroup;

/**

* La pestaña que se tira / pulsa para abrir el panel.

* Usa el atlas de Animate (quick-panel/tabSquare). Si el atlas no carga,

* dibuja un rectángulo para que el panel siga siendo usable.
  */
  class QuickPanelPullTab extends FlxSpriteGroup
  {
  public static final TAB_WIDTH:Float = 170;
  public static final TAB_HEIGHT:Float = 250;
  
  // Si la pestaña sale descentrada respecto al hitbox, ajusta estos dos valores.
  static final ATLAS_OFFSET_X:Float = 0;
  static final ATLAS_OFFSET_Y:Float = 0;
  
  var atlas:FlxAnimate = null;
  var fallback:FlxSprite = null;
  var curAnim:String = '';
  
  public function new(x:Float, y:Float, keyboard:Bool = false)
  {
  super(x, y);
  
   try
 {
 	atlas = new FlxAnimate(ATLAS_OFFSET_X, ATLAS_OFFSET_Y);
 	Paths.loadAnimateAtlas(
 		atlas,
 		'quick-panel/' + (keyboard ? 'tabSquareKeyboard' : 'tabSquare')
 	);

 	atlas.anim.addByFrameLabel('idleLeft', 'idleLeft', 24, true);
 	atlas.anim.addByFrameLabel('idleRight', 'idleRight', 24, true);
 	atlas.anim.addByFrameLabel('held', 'held', 30, true);
 	atlas.anim.addByFrameLabel('release', 'release', 30, false);
 	atlas.anim.addByFrameLabel('pressRight', 'pressRight', 24, false);
 	atlas.anim.addByFrameLabel('pressLeft', 'pressLeft', 24, false);

 	atlas.antialiasing = true;
 	add(atlas);
 }
 catch (e:Dynamic)
 {
 	trace('QuickPanel: no se pudo cargar el atlas de la pestaña: $e');

 	atlas = null;
 	fallback = new FlxSprite(0, 0).makeGraphic(
 		Std.int(TAB_WIDTH),
 		Std.int(TAB_HEIGHT),
 		0xFF1A1A1A
 	);
 	add(fallback);
 }
  
  }
  
  public function setFlip(value:Bool):Void
  {
  if (atlas != null)
  atlas.flipX = value;
  
   if (fallback != null)
 	fallback.flipX = value;
  
  }
  
  public function playAnimation(name:String):Void
  {
  curAnim = name;
  
   if (atlas != null)
 	atlas.anim.play(name, true);
  
  }
  
  public function press(state:PanelState):Void
  {
  switch (state)
  {
  case CLOSED:
  playAnimation('pressLeft');
  
   	case OPEN:
 		playAnimation('pressRight');

 	default:
 }
  
  }
  
  public function grab(state:PanelState):Void
  {
  playAnimation('held');
  }
  
  public function release(state:PanelState):Void
  {
  switch (state)
  {
  case OPEN:
  playAnimation('release');
  
   	default:
 		playAnimation('idleLeft');
 }
  
  }
  
  public function playIdle(state:PanelState):Void
  {
  switch (state)
  {
  case CLOSED:
  playAnimation('idleLeft');
  
   	case OPENING:
 		playAnimation('held');

 	case OPEN:
 		playAnimation('idleRight');
 }
  
  }
  
  override function update(elapsed:Float):Void
  {
  super.update(elapsed);
  
   // Al terminar 'release' pasamos a idleRight.
 if (atlas != null && curAnim == 'release' && atlas.anim.finished)
 	playIdle(OPEN);
  
  }
  }
