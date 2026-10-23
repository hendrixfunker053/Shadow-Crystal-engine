package states.editors;

import backend.MenuScreenLayout;

/** Editor for Freeplay/Options visual-layout overrides. Does not instantiate QuickPanelState. */
class MenuScreenLayoutEditorState extends MusicBeatState
{
  var menu:String;
  var layout:MenuScreenLayoutFile;
  var selected:Int = 0;
  var title:FlxText;
  var values:FlxTypedGroup<FlxText>;
  var status:FlxText;
  var fields:Array<String> = ['backgroundX', 'backgroundY', 'backgroundScale', 'itemsX', 'itemsY', 'itemSpacing', 'itemScale', 'scoreX', 'scoreY', 'difficultyX', 'difficultyY'];

  public function new(targetMenu:String) { super(); menu = targetMenu; }

  override function create()
  {
    FlxG.camera.bgColor = FlxColor.BLACK;
    var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat')); bg.color = menu == 'options' ? 0xFFEA71FD : 0xFF6A78D1; bg.scrollFactor.set(); add(bg); mobile.WideScreen.fit(bg);
    title = new FlxText(16, 12, FlxG.width - 32, 'LAYOUT EDITOR: ' + menu.toUpperCase(), 24); title.setFormat(Paths.font('vcr.ttf'), FlxG.width < 700 ? 18 : 24, FlxColor.WHITE, CENTER); add(title);
    layout = MenuScreenLayout.load(menu); values = new FlxTypedGroup<FlxText>(); add(values);
    status = new FlxText(12, FlxG.height - 64, FlxG.width - 24, '', 14); status.setFormat(Paths.font('vcr.ttf'), FlxG.width < 700 ? 11 : 14, FlxColor.YELLOW, CENTER); add(status);
    refresh();
    #if mobile
    add(mobile.MobileButton.back());
    #end
    super.create();
  }

  function getValue(field:String):Float return cast Reflect.field(layout, field);
  function refresh()
  {
    values.clear();
    var small:Bool = FlxG.width < 700;
    var rowH:Float = small ? 30 : 38;
    for (i in 0...fields.length)
    {
      var field = fields[i]; var v = getValue(field);
      var label = field + ': ' + Std.string(Math.round(v * 100) / 100) + (i == selected ? '   <' : '');
      var t = new FlxText(16, 56 + i * rowH, FlxG.width - 32, label, small ? 14 : 20);
      t.setFormat(Paths.font('vcr.ttf'), small ? 14 : 20, i == selected ? FlxColor.YELLOW : FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
      values.add(t);
    }
    status.text = 'LEFT/RIGHT: ajustar | ARRIBA/ABAJO: campo | +/-: ajuste fino | S: guardar | ESC: volver';
  }

  function adjust(dir:Int, fine:Bool = false)
  {
    var field = fields[selected]; var v = getValue(field);
    var step:Float = field.toLowerCase().indexOf('scale') >= 0 ? (fine ? 0.01 : 0.05) : (fine ? 1 : 10);
    Reflect.setField(layout, field, v + dir * step); refresh();
  }

  function saveLayout()
  {
    var p = MenuScreenLayout.save(menu, layout);
    status.text = p == null ? 'No se puede guardar en esta plataforma.' : 'Guardado: ' + p;
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);
    if (controls.UI_UP_P) { selected = FlxMath.wrap(selected - 1, 0, fields.length - 1); refresh(); }
    if (controls.UI_DOWN_P) { selected = FlxMath.wrap(selected + 1, 0, fields.length - 1); refresh(); }
    if (controls.UI_LEFT_P) adjust(-1); if (controls.UI_RIGHT_P) adjust(1);
    if (FlxG.keys.justPressed.MINUS) adjust(-1, true);
if (FlxG.keys.justPressed.PLUS) adjust(1, true);
    #if mobile
    if (mobile.TouchInput.justTapped())
    {
      var ty = mobile.TouchInput.tapY; var rowH:Float = FlxG.width < 700 ? 30 : 38;
      var idx = Std.int((ty - 56) / rowH);
      if (idx >= 0 && idx < fields.length) { if (idx == selected) adjust(mobile.TouchInput.tapX < FlxG.width / 2 ? -1 : 1); else { selected = idx; refresh(); } }
    }
    #end
    if (controls.ACCEPT) saveLayout();
    if (controls.BACK) MusicBeatState.switchState(new MasterEditorMenu());
  }
}
