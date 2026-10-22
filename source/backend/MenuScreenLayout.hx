package states.editors;

import backend.MenuScreenLayout;

/**

* Editor for Freeplay/Options visual-layout overrides.

* Does not instantiate QuickPanelState.
  */
  class MenuScreenLayoutEditorState extends MusicBeatState
  {
  var menu:String;
  var layout:Dynamic;
  var selected:Int = 0;
  
  var title:FlxText;
  var values:FlxTypedGroup<FlxText>;
  var status:FlxText;
  
  var fields:Array<String> = [
  'backgroundX',
  'backgroundY',
  'backgroundScale',
  'itemsX',
  'itemsY',
  'itemSpacing',
  'itemScale',
  'scoreX',
  'scoreY',
  'difficultyX',
  'difficultyY'
  ];
  
  public function new(targetMenu:String)
  {
  super();
  menu = targetMenu;
  }
  
  override function create()
  {
  FlxG.camera.bgColor = FlxColor.BLACK;
  
   var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
 bg.color = menu == 'options' ? 0xFFEA71FD : 0xFF6A78D1;
 bg.scrollFactor.set();
 add(bg);

 #if mobile
 mobile.WideScreen.fit(bg);
 #end

 title = new FlxText(
 	16,
 	12,
 	FlxG.width - 32,
 	'LAYOUT EDITOR: ' + menu.toUpperCase(),
 	24
 );
 title.setFormat(
 	Paths.font('vcr.ttf'),
 	FlxG.width < 700 ? 18 : 24,
 	FlxColor.WHITE,
 	CENTER
 );
 add(title);

 layout = MenuScreenLayout.load(menu);

 values = new FlxTypedGroup<FlxText>();
 add(values);

 status = new FlxText(
 	12,
 	FlxG.height - 64,
 	FlxG.width - 24,
 	'',
 	14
 );
 status.setFormat(
 	Paths.font('vcr.ttf'),
 	FlxG.width < 700 ? 11 : 14,
 	FlxColor.YELLOW,
 	CENTER
 );
 add(status);

 refresh();

 #if mobile
 add(mobile.MobileButton.back());
 #end

 super.create();
  
  }
  
  function getValue(field:String):Float
  {
  var value:Dynamic = Reflect.field(layout, field);
  
   if (value == null)
 	return 0;

 return cast value;
  
  }
  
  function refresh():Void
  {
  values.clear();
  
   var small:Bool = FlxG.width < 700;
 var rowH:Float = small ? 30 : 38;

 for (i in 0...fields.length)
 {
 	var field:String = fields[i];
 	var value:Float = getValue(field);

 	var label:String = field + ': '
 		+ Std.string(Math.round(value * 100) / 100)
 		+ (i == selected ? '   <' : '');

 	var text:FlxText = new FlxText(
 		16,
 		56 + i * rowH,
 		FlxG.width - 32,
 		label,
 		small ? 14 : 20
 	);

 	text.setFormat(
 		Paths.font('vcr.ttf'),
 		small ? 14 : 20,
 		i == selected ? FlxColor.YELLOW : FlxColor.WHITE,
 		CENTER,
 		FlxTextBorderStyle.OUTLINE,
 		FlxColor.BLACK
 	);

 	values.add(text);
 }

 status.text = 'LEFT/RIGHT: ajustar | ARRIBA/ABAJO: campo | +/-: ajuste fino | S: guardar | ESC: volver';
  
  }
  
  function adjust(dir:Int, fine:Bool = false):Void
  {
  var field:String = fields[selected];
  var value:Float = getValue(field);
  
   var isScale:Bool = field.toLowerCase().indexOf('scale') >= 0;
 var step:Float = isScale
 	? (fine ? 0.01 : 0.05)
 	: (fine ? 1 : 10);

 Reflect.setField(layout, field, value + dir * step);

 refresh();
  
  }
  
  function saveLayout():Void
  {
  var path:String = MenuScreenLayout.save(menu, layout);
  
   status.text = path == null
 	? 'No se puede guardar en esta plataforma.'
 	: 'Guardado: ' + path;
  
  }
  
  override function update(elapsed:Float)
  {
  super.update(elapsed);
  
   if (controls.UI_UP_P)
 {
 	selected = FlxMath.wrap(selected - 1, 0, fields.length - 1);
 	refresh();
 }

 if (controls.UI_DOWN_P)
 {
 	selected = FlxMath.wrap(selected + 1, 0, fields.length - 1);
 	refresh();
 }

 if (controls.UI_LEFT_P)
 	adjust(-1);

 if (controls.UI_RIGHT_P)
 	adjust(1);

 if (FlxG.keys.justPressed.MINUS)
 	adjust(-1, true);

 // PLUS es compatible con FlxKeyList; EQUAL no existe en tu fork.
 if (FlxG.keys.justPressed.PLUS)
 	adjust(1, true);

 if (FlxG.keys.justPressed.S)
 	saveLayout();

 #if mobile
 if (mobile.TouchInput.justTapped())
 {
 	var touchY:Float = mobile.TouchInput.tapY;
 	var rowH:Float = FlxG.width < 700 ? 30 : 38;
 	var index:Int = Std.int((touchY - 56) / rowH);

 	if (index >= 0 && index < fields.length)
 	{
 		if (index == selected)
 		{
 			adjust(mobile.TouchInput.tapX < FlxG.width / 2 ? -1 : 1);
 		}
 		else
 		{
 			selected = index;
 			refresh();
 		}
 	}
 }
 #end

 if (controls.ACCEPT)
 	saveLayout();

 if (controls.BACK)
 	MusicBeatState.switchState(new MasterEditorMenu());
  
  }
  }
