
package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.group.FlxGroup.FlxTypedGroup;

class CrystalHUDStudioState extends MusicBeatState
{
    static inline var FONT:String = "FunkinOptions.otf";

    var purple:FlxColor = 0xFF914DFF;
    var dark:FlxColor = 0xFF100E16;
    var panelColor:FlxColor = 0xFF191620;

    var toolbox:FlxTypedGroup<FlxText>;
    var workspaceBlocks:FlxTypedGroup<FlxSprite>;
    var blockLabels:FlxTypedGroup<FlxText>;

    var categoryButtons:Array<FlxText> = [];
    var availableBlocks:Array<String> = [];

    var selectedCategory:Int = 0;
    var selectedBlock:Int = -1;

    var dragging:Bool = false;
    var dragIndex:Int = -1;
    var dragOffsetX:Float = 0;
    var dragOffsetY:Float = 0;

    var previewText:FlxText;
    var propertiesText:FlxText;

    var codeBackground:FlxSprite;
    var codeWindow:FlxText;

    var showCode:Bool = false;

    var headerButtons:Array<FlxText> = [];

    var categories:Array<String> = [
        "EVENTS",
        "OBJECTS",
        "PROPERTIES",
        "ANIMATIONS",
        "LOGIC",
        "VARIABLES",
        "GAME DATA"
    ];

    var blockData:Array<Array<String>> = [
        [
            "When song starts",
            "When step hits",
            "When beat hits",
            "When song ends"
        ],
        [
            "Create text",
            "Create sprite",
            "Remove object",
            "Add to HUD"
        ],
        [
            "Set position",
            "Set scale",
            "Set alpha",
            "Set visibility"
        ],
        [
            "Tween X",
            "Tween Y",
            "Tween Alpha",
            "Tween Scale"
        ],
        [
            "If",
            "If / Else",
            "Repeat",
            "Forever"
        ],
        [
            "Set variable",
            "Change variable",
            "Get variable"
        ],
        [
            "Get score",
            "Get combo",
            "Get misses",
            "Get health",
            "Get song position"
        ]
    ];

    override function create()
    {
        super.create();

        FlxG.camera.bgColor = 0xFF08070C;
        FlxG.mouse.visible = true;

        createBackground();
        createHeader();
        createToolbox();
        createWorkspace();
        createPreview();
        createProperties();

        changeCategory(0);

        #if mobile
        add(mobile.MobileButton.back());
        #end
    }

    // --------------------------------------------------
    // BACKGROUND
    // --------------------------------------------------

    function createBackground()
    {
        var bg = new FlxSprite().makeGraphic(
            FlxG.width,
            FlxG.height,
            0xFF08070C
        );

        add(bg);
    }

    // --------------------------------------------------
    // HEADER
    // --------------------------------------------------

    function createHeader()
    {
        var header = new FlxSprite(
            0, 0
        ).makeGraphic(
            FlxG.width, 55, 0xFF121019
        );

        add(header);

        addLine(0, 54, FlxG.width, 2, purple);

        var title = createText(
            15, 12, 350,
            "CRYSTAL HUD STUDIO",
            24,
            FlxColor.WHITE
        );

        add(title);

        addHeaderButton("PREVIEW", FlxG.width - 335);
        addHeaderButton("EXPORT LUA", FlxG.width - 215);
        addHeaderButton("BACK", FlxG.width - 100);
    }

    function addHeaderButton(text:String, x:Float)
    {
        var button = createText(
            x, 18, 110,
            text, 15, 0xFFD9C4FF
        );

        button.alignment = CENTER;
        button.borderStyle = FlxTextBorderStyle.OUTLINE;
        button.borderColor = 0xFF6132A0;

        headerButtons.push(button);
        add(button);
    }

    // --------------------------------------------------
    // TOOLBOX
    // --------------------------------------------------

    function createToolbox()
    {
        var panel = new FlxSprite(
            0, 56
        ).makeGraphic(
            190, FlxG.height - 56,
            0xFF121019
        );

        add(panel);

        addLine(189, 56, 2, FlxG.height, purple);

        add(createText(
            13, 70, 165,
            "CATEGORIES", 18, purple
        ));

        toolbox = new FlxTypedGroup<FlxText>();
        add(toolbox);

        for (i in 0...categories.length)
        {
            var item = createText(
                13,
                112 + i * 43,
                165,
                categories[i],
                15,
                FlxColor.WHITE
            );

            item.ID = i;

            categoryButtons.push(item);
            toolbox.add(item);
        }
    }

    function changeCategory(index:Int)
    {
        selectedCategory = index;
        availableBlocks = blockData[index].copy();

        for (item in categoryButtons)
        {
            item.color = item.ID == index
                ? purple
                : FlxColor.WHITE;
        }

        refreshToolbox();
    }

    function refreshToolbox()
    {
        // Limpiar los bloques anteriores.
        for (member in blockList.members)
        {
            if (member != null)
            {
                remove(member);
                member.destroy();
            }
        }

        blockList.clear();

        for (i in 0...availableBlocks.length)
        {
            var block = createText(
                205,
                145 + i * 48,
                245,
                "  " + availableBlocks[i],
                15,
                FlxColor.WHITE
            );

            block.background = true;
            block.backgroundColor = getCategoryColor(selectedCategory);
            block.ID = i;

            blockList.add(block);
        }
    }

    var blockList:FlxTypedGroup<FlxText>;

    // --------------------------------------------------
    // WORKSPACE
    // --------------------------------------------------

    function createWorkspace()
    {
        var workspace = new FlxSprite(
            190, 56
        ).makeGraphic(
            Std.int(FlxG.width * 0.47),
            FlxG.height - 56,
            0xFF17151D
        );

        add(workspace);

        addLine(190, 56, 2, FlxG.height, purple);

        add(createText(
            205, 70, 300,
            "WORKSPACE", 18, purple
        ));

        add(createText(
            205, 95, 400,
            "Drag blocks here to build your HUD",
            12, 0xFF898493
        ));

        workspaceBlocks = new FlxTypedGroup<FlxSprite>();
        add(workspaceBlocks);

        blockLabels = new FlxTypedGroup<FlxText>();
        add(blockLabels);

        blockList = new FlxTypedGroup<FlxText>();
        add(blockList);
    }

    function addWorkspaceBlock(name:String)
    {
        var index = workspaceBlocks.length;

        var x:Float = 220;
        var y:Float = 145 + index * 55;

        var block = new FlxSprite(x, y).makeGraphic(
            220, 43,
            getCategoryColor(selectedCategory)
        );

        workspaceBlocks.add(block);

        var label = createText(
            x + 9,
            y + 11,
            205,
            name,
            14,
            FlxColor.WHITE
        );

        blockLabels.add(label);

        selectedBlock = index;

        FlxG.sound.play(Paths.sound('scrollMenu'), 0.3);

        updateProperties();
    }

    // --------------------------------------------------
    // PREVIEW
    // --------------------------------------------------

    function createPreview()
    {
        var x = Std.int(FlxG.width * 0.68);

        var preview = new FlxSprite(
            x, 56
        ).makeGraphic(
            FlxG.width - x,
            Std.int(FlxG.height * 0.52),
            0xFF050505
        );

        add(preview);

        addLine(x, 56, 2, FlxG.height, purple);

        add(createText(
            x + 12, 70, 250,
            "HUD PREVIEW", 18, purple
        ));

        previewText = createText(
            x + 15,
            175,
            FlxG.width - x - 30,
            "SCORE: 000000\nCOMBO: 0",
            19,
            FlxColor.WHITE
        );

        previewText.alignment = CENTER;
        add(previewText);

        add(createText(
            x + 12,
            112,
            250,
            "16:9 - PREVIEW MODE",
            11,
            0xFF77717F
        ));
    }

    // --------------------------------------------------
    // PROPERTIES
    // --------------------------------------------------

    function createProperties()
    {
        var x = Std.int(FlxG.width * 0.68);
        var y = Std.int(FlxG.height * 0.59);

        var panel = new FlxSprite(
            x, y
        ).makeGraphic(
            FlxG.width - x,
            FlxG.height - y,
            0xFF121019
        );

        add(panel);

        addLine(x, y, FlxG.width - x, 2, purple);

        add(createText(
            x + 12,
            y + 12,
            250,
            "PROPERTIES",
            18,
            purple
        ));

        propertiesText = createText(
            x + 12,
            y + 48,
            FlxG.width - x - 20,
            "Select a block to inspect its properties.",
            13,
            FlxColor.WHITE
        );

        add(propertiesText);
    }

    function updateProperties()
    {
        if (selectedBlock < 0 ||
            selectedBlock >= blockLabels.length)
            return;

        propertiesText.text =
            "Selected block:\n" +
            blockLabels.members[selectedBlock].text +
            "\n\nPosition: " +
            Std.int(workspaceBlocks.members[selectedBlock].x) +
            ", " +
            Std.int(workspaceBlocks.members[selectedBlock].y);
    }

    // --------------------------------------------------
    // COLORS
    // --------------------------------------------------

    function getCategoryColor(index:Int):FlxColor
    {
        return switch(index)
        {
            case 0: 0xFFB38B26;
            case 1: 0xFF269C55;
            case 2: 0xFF287BC0;
            case 3: 0xFFD77B26;
            case 4: 0xFF8544C5;
            case 5: 0xFFCC6630;
            default: 0xFF2789B9;
        };
    }

    // --------------------------------------------------
    // LUA EXPORTER
    // --------------------------------------------------

    function generateLua():String
    {
        var lua:String =
            "-- Crystal HUD Studio\n" +
            "-- Generated Lua Script\n\n";

        var createCode:String = "";
        var updateCode:String = "";
        var stepCode:String = "";
        var beatCode:String = "";

        for (i in 0...blockLabels.length)
        {
            var name = blockLabels.members[i].text.trim();

            switch(name)
            {
                case "When song starts":
                    createCode += "-- Song start event\n";

                case "When step hits":
                    stepCode += "-- Step event\n";

                case "When beat hits":
                    beatCode += "-- Beat event\n";

                case "Create text":
                    createCode +=
                        "makeLuaText('myText', 'Hello!', 200, 100, 100)\n" +
                        "setTextSize('myText', 24)\n" +
                        "addLuaText('myText')\n";

                case "Create sprite":
                    createCode +=
                        "-- Add your sprite here\n";

                case "Remove object":
                    createCode +=
                        "removeLuaSprite('mySprite', true)\n";

                case "Add to HUD":
                    createCode +=
                        "setObjectCamera('myText', 'hud')\n";

                case "Set position":
                    createCode +=
                        "setProperty('myText.x', 100)\n" +
                        "setProperty('myText.y', 100)\n";

                case "Set scale":
                    createCode +=
                        "scaleObject('myText', 1, 1)\n";

                case "Set alpha":
                    createCode +=
                        "setProperty('myText.alpha', 1)\n";

                case "Set visibility":
                    createCode +=
                        "setProperty('myText.visible', true)\n";

                case "Tween X":
                    createCode +=
                        "doTweenX('moveHUD', 'myText', 300, 1, 'quadOut')\n";

                case "Tween Y":
                    createCode +=
                        "doTweenY('moveHUDY', 'myText', 200, 1, 'quadOut')\n";

                case "Tween Alpha":
                    createCode +=
                        "doTweenAlpha('fadeHUD', 'myText', 0, 1, 'linear')\n";

                case "Tween Scale":
                    createCode +=
                        "doTweenX('scaleHUD', 'myText.scale', 1.2, 1, 'quadOut')\n";

                case "Get score":
                    updateCode +=
                        "local score = getProperty('songScore')\n";

                case "Get combo":
                    updateCode +=
                        "local currentCombo = getProperty('combo')\n";

                case "Get misses":
                    updateCode +=
                        "local misses = getProperty('songMisses')\n";

                case "Get health":
                    updateCode +=
                        "local health = getProperty('health')\n";

                case "Get song position":
                    updateCode +=
                        "local songPosition = getSongPosition()\n";

                default:
                    lua += "-- Block: " + name + "\n";
            }
        }

        if (createCode.length > 0)
        {
            lua += "function onCreatePost()\n";
            lua += createCode;
            lua += "end\n\n";
        }

        if (updateCode.length > 0)
        {
            lua += "function onUpdate(elapsed)\n";
            lua += updateCode;
            lua += "end\n\n";
        }

        if (stepCode.length > 0)
        {
            lua += "function onStepHit()\n";
            lua += stepCode;
            lua += "end\n\n";
        }

        if (beatCode.length > 0)
        {
            lua += "function onBeatHit()\n";
            lua += beatCode;
            lua += "end\n\n";
        }

        return lua;
    }

    // --------------------------------------------------
    // CODE WINDOW
    // --------------------------------------------------

    function showCodeWindow()
    {
        if (showCode)
        {
            hideCodeWindow();
            return;
        }

        showCode = true;

        codeBackground = new FlxSprite(
            0, 0
        ).makeGraphic(
            FlxG.width,
            FlxG.height,
            0xEE08070C
        );

        add(codeBackground);

        codeWindow = createText(
            35, 75,
            FlxG.width - 70,
            generateLua(),
            15,
            FlxColor.WHITE
        );

        codeWindow.borderStyle = FlxTextBorderStyle.OUTLINE;
        codeWindow.borderColor = 0xFF000000;

        add(codeWindow);

        var close = createText(
            FlxG.width - 120,
            25,
            100,
            "CLOSE [ESC]",
            15,
            purple
        );

        close.ID = 999;
        add(close);
        closeButton = close;
    }

    var closeButton:FlxText;

    function hideCodeWindow()
    {
        showCode = false;

        remove(codeBackground);
        remove(codeWindow);
        remove(closeButton);

        codeBackground.destroy();
        codeWindow.destroy();
        closeButton.destroy();
    }

    // --------------------------------------------------
    // TEXT HELPERS
    // --------------------------------------------------

    function createText(
        x:Float,
        y:Float,
        width:Float,
        text:String,
        size:Int,
        color:FlxColor
    ):FlxText
    {
        var result = new FlxText(
            x, y, width, text, size
        );

        result.setFormat(
            Paths.font(FONT),
            size,
            color,
            LEFT
        );

        result.scrollFactor.set();

        return result;
    }

    function addLine(
        x:Float,
        y:Float,
        width:Int,
        height:Int,
        color:FlxColor
    )
    {
        var line = new FlxSprite(x, y).makeGraphic(
            width, height, color
        );

        add(line);
    }

    // --------------------------------------------------
    // UPDATE
    // --------------------------------------------------

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (showCode)
        {
            if (FlxG.keys.justPressed.ESCAPE)
                hideCodeWindow();

            if (closeButton != null &&
                FlxG.mouse.justPressed &&
                FlxG.mouse.overlaps(closeButton))
            {
                hideCodeWindow();
            }

            return;
        }

        // CATEGORIES
        if (FlxG.mouse.justPressed)
        {
            for (item in categoryButtons)
            {
                if (FlxG.mouse.overlaps(item))
                {
                    changeCategory(item.ID);
                    break;
                }
            }

            // TOOLBOX BLOCKS
            for (item in blockList.members)
            {
                if (item != null && FlxG.mouse.overlaps(item))
                {
                    addWorkspaceBlock(
                        availableBlocks[item.ID]
                    );
                    break;
                }
            }

            // WORKSPACE BLOCKS
            for (i in 0...workspaceBlocks.length)
            {
                var block = workspaceBlocks.members[i];

                if (block != null && FlxG.mouse.overlaps(block))
                {
                    dragging = true;
                    dragIndex = i;
                    selectedBlock = i;

                    dragOffsetX = FlxG.mouse.x - block.x;
                    dragOffsetY = FlxG.mouse.y - block.y;

                    updateProperties();
                    break;
                }
            }

            // HEADER BUTTONS
            for (i in 0...headerButtons.length)
            {
                var button = headerButtons[i];

                if (FlxG.mouse.overlaps(button))
                {
                    switch(i)
                    {
                        case 0:
                            previewText.text =
                                "SCORE: 000000\nCOMBO: 0";

                        case 1:
                            showCodeWindow();

                        case 2:
                            MusicBeatState.switchState(
                                new MasterEditorMenu()
                            );
                    }
                }
            }
        }

        // DRAGGING
        if (dragging && dragIndex >= 0)
        {
            if (FlxG.mouse.pressed)
            {
                var block = workspaceBlocks.members[dragIndex];
                var label = blockLabels.members[dragIndex];

                block.x = FlxG.mouse.x - dragOffsetX;
                block.y = FlxG.mouse.y - dragOffsetY;

                label.x = block.x + 9;
                label.y = block.y + 11;

                updateProperties();
            }

            if (FlxG.mouse.justReleased)
            {
                dragging = false;
                dragIndex = -1;
            }
        }

        if (controls.BACK)
        {
            MusicBeatState.switchState(
                new MasterEditorMenu()
            );
        }
    }

    override function destroy()
    {
        FlxG.mouse.visible = false;
        super.destroy();
    }
}
