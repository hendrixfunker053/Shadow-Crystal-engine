package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Shadow Crystal Engine - Egg Room Easter Egg. */
class EggRoomState extends MusicBeatState
{
    var kris:FlxSprite;
    var treeBack:FlxSprite;
    var treeMid:FlxSprite;
    var treeTop:FlxSprite;
    var message:FlxText;
    var prompt:FlxText;
    var buttons:Array<FlxText> = [];
    var moveSpeed:Float = 170;
    var direction:String = "down";
    var nearTree:Bool = false;
    var talked:Bool = false;
    var leaving:Bool = false;

    override function create()
    {
        super.create();
        #if DISCORD_ALLOWED
        DiscordClient.changePresence("Somewhere in between", null);
        #end

        FlxG.camera.bgColor = 0xFF160D18;

        // Keep the room art on-screen. The previous package placed these layers
        // at large negative coordinates, which made the room appear completely black.
        var bg = new FlxSprite(0, 0).loadGraphic(Paths.image("eggroom/eggRoom"));
        bg.setGraphicSize(FlxG.width, FlxG.height);
        bg.updateHitbox();
        bg.antialiasing = false;
        bg.scrollFactor.set();
        add(bg);

        // The three tree pieces are layered together as one large foreground prop.
        var treeX:Float = FlxG.width * 0.34;
        var treeY:Float = FlxG.height * 0.17;
        treeBack = new FlxSprite(treeX, treeY).loadGraphic(Paths.image("eggroom/treeBot"));
        treeBack.setGraphicSize(Std.int(treeBack.width * 3.0));
        treeBack.updateHitbox();
        treeBack.antialiasing = false;
        treeBack.scrollFactor.set();
        add(treeBack);

        kris = new FlxSprite(FlxG.width * 0.46, FlxG.height * 0.58);
        kris.frames = Paths.getSparrowAtlas("eggroom/kris");
        kris.animation.addByPrefix("down", "kris down", 8, true);
        kris.animation.addByPrefix("left", "kris left", 8, true);
        kris.animation.addByPrefix("right", "kris right", 8, true);
        kris.animation.addByPrefix("up", "kris up", 8, true);
        kris.animation.play("down");
        kris.setGraphicSize(Std.int(kris.width * 2.5));
        kris.updateHitbox();
        kris.antialiasing = false;
        kris.scrollFactor.set();
        add(kris);

        treeMid = new FlxSprite(treeX, treeY).loadGraphic(Paths.image("eggroom/treeMid"));
        treeMid.setGraphicSize(Std.int(treeMid.width * 3.0));
        treeMid.updateHitbox();
        treeMid.antialiasing = false;
        treeMid.scrollFactor.set();
        add(treeMid);

        treeTop = new FlxSprite(treeX, treeY).loadGraphic(Paths.image("eggroom/treeTop"));
        treeTop.setGraphicSize(Std.int(treeTop.width * 3.0));
        treeTop.updateHitbox();
        treeTop.antialiasing = false;
        treeTop.scrollFactor.set();
        add(treeTop);

        message = new FlxText(24, FlxG.height - 112, FlxG.width - 48, "", 18);
        message.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        message.scrollFactor.set();
        message.visible = false;
        add(message);

        prompt = new FlxText(24, FlxG.height - 34, FlxG.width - 48, "Find the way out.", 14);
        prompt.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        prompt.scrollFactor.set();
        add(prompt);

        #if mobile
        createTouchControls();
        add(mobile.MobileButton.back(null, false));
        #end

        #if ACHIEVEMENTS_ALLOWED
        Achievements.unlock("well_there_is_a_man_here");
        #end
    }

    #if mobile
    function createTouchControls():Void
    {
        addTouchButton("▲", 76, FlxG.height - 174, "up");
        addTouchButton("◀", 24, FlxG.height - 122, "left");
        addTouchButton("▶", 128, FlxG.height - 122, "right");
        addTouchButton("▼", 76, FlxG.height - 70, "down");
        addTouchButton("OK", FlxG.width - 96, FlxG.height - 112, "interact");
    }

    function addTouchButton(label:String, x:Float, y:Float, action:String):Void
    {
        var b = new FlxText(x, y, 48, label, 28);
        b.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.GRAY);
        b.scrollFactor.set();
        b.alpha = 0.8;
        b.ID = buttons.length;
        // Button action is resolved from its stable ID below.
        buttons.push(b);
        add(b);
    }
    #end

    override function update(elapsed:Float)
    {
        if (leaving) { super.update(elapsed); return; }

        var dx:Float = 0;
        var dy:Float = 0;
        if (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A) { dx = -1; direction = "left"; }
        else if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D) { dx = 1; direction = "right"; }
        if (FlxG.keys.pressed.UP || FlxG.keys.pressed.W) { dy = -1; direction = "up"; }
        else if (FlxG.keys.pressed.DOWN || FlxG.keys.pressed.S) { dy = 1; direction = "down"; }

        #if mobile
        if (mobile.TouchInput.justTapped())
        {
            for (b in buttons)
            {
                if (mobile.TouchInput.tappedOn(b))
                {
                    var action:String = ["up", "left", "right", "down", "interact"][b.ID];
                    switch (action)
                    {
                        case "up": dy = -1; direction = "up";
                        case "down": dy = 1; direction = "down";
                        case "left": dx = -1; direction = "left";
                        case "right": dx = 1; direction = "right";
                        case "interact": interact();
                    }
                    mobile.TouchInput.consumeTap();
                    break;
                }
            }
        }
        #end

        if (dx != 0 || dy != 0)
        {
            // Touch input is a tap, so move a useful fixed step; keyboard remains smooth.
            var step:Float = moveSpeed * elapsed;
            #if mobile
            if (mobile.TouchInput.justTapped()) step = 28;
            #end
            kris.x += dx * step;
            kris.y += dy * step;
            kris.x = FlxMath.bound(kris.x, 0, FlxG.width - kris.width);
            kris.y = FlxMath.bound(kris.y, 0, FlxG.height - kris.height - 72);
            kris.animation.play(direction);
            prompt.text = "Keep looking.";
        }

        nearTree = FlxG.overlap(kris, treeMid) || FlxG.overlap(kris, treeTop) || FlxG.overlap(kris, treeBack);
        if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.Z) interact();
        if (FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE) returnToMenu();
        super.update(elapsed);
    }

    function interact():Void
    {
        message.visible = true;
        if (!nearTree)
            message.text = "* (It is quiet here.)";
        else if (!talked)
        {
            talked = true;
            message.text = "* (He is behind the tree.)
* (It is a tree.)
* (Well, there is a man here.)";
            prompt.text = "There is nothing else to say.";
        }
        else message.text = "* ( ... )";
    }

    function returnToMenu():Void
    {
        if (leaving) return;
        leaving = true;
        MusicBeatState.switchState(new MainMenuState());
    }
}
