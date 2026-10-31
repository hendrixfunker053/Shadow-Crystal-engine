
package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.group.FlxGroup.FlxTypedGroup;

class CrystalHUDStudioState extends MusicBeatState
{
    static inline var FONT:String = "FunkinOptions.otf";

    var purple:FlxColor = 0xFF914DFF;

    var categoryButtons:Array<FlxText> = [];
    var headerButtons:Array<FlxText> = [];

    var toolbox:FlxTypedGroup<FlxText>;
    var blockList:FlxTypedGroup<FlxSprite>;
    var blockListLabels:FlxTypedGroup<FlxText>;

    var workspaceBlocks:FlxTypedGroup<FlxSprite>;
    var blockLabels:FlxTypedGroup<FlxText>;

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
    var closeButton:FlxText;

    var showCode:Bool = false;
    var previewVisible:Bool = true;

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
        var header = new FlxSprite().makeGraphic(
            FlxG.width,
            55,
            0xFF121019
        );

        add(header);
        addLine(0, 54, FlxG.width, 2, purple);

        add(createText(
            15, 12, 350,
            "CRYSTAL HUD STUDIO",
            24,
            FlxColor.WHITE
        ));

        addHeaderButton("PREVIEW", FlxG.width - 335);
        addHeaderButton("EXPORT LUA", FlxG.width - 215);
        addHeaderButton("BACK", FlxG.width - 100);
    }

    function addHeaderButton(text:String, x:Float)
    {
        var button = createText(
            x, 18, 110,
            text,
            15,
            0xFFD9C4FF
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
        var panel = new FlxSprite(0, 56).makeGraphic(
            190,
            FlxG.height - 56,
            0xFF121019
        );

        add(panel);
        addLine(189, 56, 2, FlxG.height, purple);

        add(createText(
            13, 70, 165,
            "CATEGORIES",
            18,
            purple
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

        blockList = new FlxTypedGroup<FlxSprite>();
        add(blockList);

        blockListLabels = new FlxTypedGroup<FlxText>();
        add(blockListLabels);
    }

    function changeCategory(index:Int)
    {
        if (index < 0 || index >= categories.length)
            return;

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
        for (member in blockList.members.copy())
        {
            if (member != null)
            {
                blockList.remove(member);
                member.destroy();
            }
        }

        for (member in blockListLabels.members.copy())
        {
            if (member != null)
            {
                blockListLabels.remove(member);
                member.destroy();
            }
        }

        for (i in 0...availableBlocks.length)
        {
            var y = 145 + i * 48;

            var block = new FlxSprite(205, y).makeGraphic(
                245,
                38,
                getCategoryColor(selectedCategory)
            );

            blockList.add(block);

            var label = createText(
                214,
                y + 10,
                225,
                availableBlocks[i],
                14,
                FlxColor.WHITE
            );

            label.ID = i;
            blockListLabels.add(label);
        }
    }

    // --------------------------------------------------
    // WORKSPACE
    // --------------------------------------------------

    function createWorkspace()
    {
        var workspaceWidth = Std.int(FlxG.width * 0.47);

        var workspace = new FlxSprite(190, 56).makeGraphic(
            workspaceWidth,
            FlxG.height - 56,
            0xFF17151D
        );

        add(workspace);

        addLine(190, 56, 2, FlxG.height, purple);

        add(createText(
            205, 70, 300,
            "WORKSPACE",
            18,
            purple
        ));

        add(createText(
            205, 95, 400,
            "Select a toolbox block to add it here.",
            12,
            0xFF898493
        ));

        workspaceBlocks = new FlxTypedGroup<FlxSprite>();
        add(workspaceBlocks);

        blockLabels = new FlxTypedGroup<FlxText>();
        add(blockLabels);
    }

    function addWorkspaceBlock(name:String)
    {
        var index = workspaceBlocks.length;

        var x:Float = 220;
        var y:Float = 145 + index * 55;

        var block = new FlxSprite(x, y).makeGraphic(
            220,
            43,
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

        FlxG.sound.play(
            Paths.sound("scrollMenu"),
            0.3
        );

        updateProperties();
    }

    function removeSelectedBlock()
    {
        if (selectedBlock < 0 ||
            selectedBlock >= workspaceBlocks.length)
            return;

        var block = workspaceBlocks.members[selectedBlock];
        var label = blockLabels.members[selectedBlock];

        if (block != null)
        {
            workspaceBlocks.remove(block, true);
            block.destroy();
        }

        if (label != null)
        {
            blockLabels.remove(label, true);
            label.destroy();
        }

        selectedBlock = -1;
        dragging = false;
        dragIndex = -1;

        updateProperties();
    }

    // --------------------------------------------------
    // PREVIEW
    // --------------------------------------------------

    function createPreview()
    {
        var x = Std.int(FlxG.width * 0.68);

        var preview = new FlxSprite(x, 56).makeGraphic(
            FlxG.width - x,
            Std.int(FlxG.height * 0.52),
            0xFF050505
        );

        add(preview);

        addLine(x, 56, 2, FlxG.height, purple);

        add(createText(
            x + 12, 70, 250,
            "HUD PREVIEW",
            18,
            purple
        ));

        add(createText(
            x + 12,
            112,
            250,
            "16:9 - PREVIEW MODE",
            11,
            0xFF77717F
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
    }

    function togglePreview()
    {
        previewVisible = !previewVisible;

        previewText.visible = previewVisible;
    }

    // --------------------------------------------------
    // PROPERTIES
    // --------------------------------------------------

    function createProperties()
    {
        var x = Std.int(FlxG.width * 0.68);
        var y = Std.int(FlxG.height * 0.59);

        var panel = new FlxSprite(x, y).makeGraphic(
            FlxG.width - x,
            FlxG.height - y,
            0xFF121019
        );

        add(panel);

        addLine(
            x,
            y,
            FlxG.width - x,
            2,
            purple
        );

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
        if (propertiesText == null)
            return;

        if (selectedBlock < 0 ||
            selectedBlock >= workspaceBlocks.length)
        {
            propertiesText.text =
                "No block selected.\n\n" +
                "Select a block in the workspace.";

            return;
        }

        var block = workspaceBlocks.members[selectedBlock];
        var label = blockLabels.members[selectedBlock];

        if (block == null || label == null)
            return;

        propertiesText.text =
            "Selected block:\n" +
            label.text +
            "\n\nPosition:\n" +
            Std.int(block.x) +
            ", " +
            Std.int(block.y) +
            "\n\nBlock ID:\n" +
            selectedBlock +
            "\n\nCategory:\n" +
            categories[selectedCategory] +
            "\n\nDELETE - Remove selected block";
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
    // LUA GENERATOR
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
        var endCode:String = "";

        var currentEvent:String = "create";

        for (i in 0...blockLabels.length)
        {
            var label = blockLabels.members[i];

            if (label == null)
                continue;

            var name = StringTools.trim(label.text);
            var code:String = "";

            switch(name)
            {
                case "When song starts":
                    currentEvent = "create";

                case "When step hits":
                    currentEvent = "step";

                case "When beat hits":
                    currentEvent = "beat";

                case "When song ends":
                    currentEvent = "end";

                case "Create text":
                    code =
                        "makeLuaText('myText', 'Hello!', 200, 100, 100)\n" +
                        "setTextSize('myText', 24)\n" +
                        "addLuaText('myText')\n";

                case "Create sprite":
                    code =
                        "-- Create your sprite here\n" +
                        "-- Example: makeLuaSprite('mySprite', 'image', 100, 100)\n";

                case "Remove object":
                    code =
                        "removeLuaSprite('mySprite', true)\n";

                case "Add to HUD":
                    code =
                        "setObjectCamera('myText', 'hud')\n";

                case "Set position":
                    code =
                        "setProperty('myText.x', 100)\n" +
                        "setProperty('myText.y', 100)\n";

                case "Set scale":
                    code =
                        "scaleObject('myText', 1, 1)\n";

                case "Set alpha":
                    code =
                        "setProperty('myText.alpha', 1)\n";

                case "Set visibility":
                    code =
                        "setProperty('myText.visible', true)\n";

                case "Tween X":
                    code =
                        "doTweenX('moveHUD', 'myText', 300, 1, 'quadOut')\n";

                case "Tween Y":
                    code =
                        "doTweenY('moveHUDY', 'myText', 200, 1, 'quadOut')\n";

                case "Tween Alpha":
                    code =
                        "doTweenAlpha('fadeHUD', 'myText', 0, 1, 'linear')\n";

                case "Tween Scale":
                    code =
                        "doTweenX('scaleHUD', 'myText.scale', 1.2, 1, 'quadOut')\n";

                case "If":
                    code = "-- TODO: Add condition\n";

                case "If / Else":
                    code = "-- TODO: Add if/else condition\n";

                case "Repeat":
                    code = "-- TODO: Add repeat block\n";

                case "Forever":
                    code = "-- TODO: Add loop block\n";

                case "Set variable":
                    code =
                        "local myVariable = 0\n";

                case "Change variable":
                    code =
                        "myVariable = myVariable + 1\n";

                case "Get variable":
                    code =
                        "debugPrint(myVariable)\n";

                case "Get score":
                    code =
                        "local score = getProperty('songScore')\n";

                case "Get combo":
                    code =
                        "local currentCombo = getProperty('combo')\n";

                case "Get misses":
                    code =
                        "local misses = getProperty('songMisses')\n";

                case "Get health":
                    code =
                        "local health = getProperty('health')\n";

                case "Get song position":
                    code =
                        "local songPosition = getSongPosition()\n";

                default:
                    code = "-- Unknown block: " + name + "\n";
            }

            switch(currentEvent)
            {
                case "create":
                    createCode += code;

                case "step":
                    stepCode += code;

                case "beat":
                    beatCode += code;

                case "end":
                    endCode += code;

                default:
                    updateCode += code;
            }
        }

        if (createCode.length > 0)
        {
            lua +=
                "function onCreatePost()\n" +
                createCode +
                "end\n\n";
        }

        if (updateCode.length > 0)
        {
            lua +=
                "function onUpdate(elapsed)\n" +
                updateCode +
                "end\n\n";
        }

        if (stepCode.length > 0)
        {
            lua +=
                "function onStepHit()\n" +
                stepCode +
                "end\n\n";
        }

        if (beatCode.length > 0)
        {
            lua +=
                "function onBeatHit()\n" +
                beatCode +
                "end\n\n";
        }

        if (endCode.length > 0)
        {
            lua +=
                "function onEndSong()\n" +
                endCode +
                "end\n\n";
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

        codeBackground = new FlxSprite().makeGraphic(
            FlxG.width,
            FlxG.height,
            0xEE08070C
        );

        add(codeBackground);

        var title = createText(
            35,
            25,
            400,
            "GENERATED LUA",
            22,
            purple
        );

        add(title);

        codeWindow = createText(
            35,
            75,
            FlxG.width - 70,
            generateLua(),
            15,
            FlxColor.WHITE
        );

        codeWindow.borderStyle = FlxTextBorderStyle.OUTLINE;
        codeWindow.borderColor = 0xFF000000;

        add(codeWindow);

        closeButton = createText(
            FlxG.width - 130,
            25,
            110,
            "CLOSE [ESC]",
            15,
            purple
        );

        add(closeButton);
    }

    function hideCodeWindow()
    {
        if (!showCode)
            return;

        showCode = false;

        if (codeBackground != null)
        {
            remove(codeBackground);
            codeBackground.destroy();
            codeBackground = null;
        }

        if (codeWindow != null)
        {
            remove(codeWindow);
            codeWindow.destroy();
            codeWindow = null;
        }

        if (closeButton != null)
        {
            remove(closeButton);
            closeButton.destroy();
            closeButton = null;
        }
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
            x,
            y,
            width,
            text,
            size
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
            width,
            height,
            color
        );

        add(line);
    }

    // --------------------------------------------------
    // UPDATE
    // --------------------------------------------------

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        // CODE WINDOW
        if (showCode)
        {
            if (FlxG.keys.justPressed.ESCAPE)
            {
                hideCodeWindow();
                return;
            }

            if (closeButton != null &&
                FlxG.mouse.justPressed &&
                FlxG.mouse.overlaps(closeButton))
            {
                hideCodeWindow();
            }

            return;
        }

        // DELETE SELECTED BLOCK
        if (FlxG.keys.justPressed.DELETE ||
            FlxG.keys.justPressed.BACKSPACE)
        {
            removeSelectedBlock();
        }

        // MOUSE CLICK
        if (FlxG.mouse.justPressed)
        {
            var clickedUI:Bool = false;

            // HEADER BUTTONS
            for (i in 0...headerButtons.length)
            {
                var button = headerButtons[i];

                if (FlxG.mouse.overlaps(button))
                {
                    clickedUI = true;

                    switch(i)
                    {
                        case 0:
                            togglePreview();

                        case 1:
                            showCodeWindow();

                        case 2:
                            MusicBeatState.switchState(
                                new MasterEditorMenu()
                            );
                    }

                    break;
                }
            }

            if (clickedUI)
                return;

            // CATEGORIES
            for (item in categoryButtons)
            {
                if (FlxG.mouse.overlaps(item))
                {
                    changeCategory(item.ID);
                    clickedUI = true;
                    break;
                }
            }

            if (clickedUI)
                return;

            // TOOLBOX
            for (i in 0...blockList.length)
            {
                var block = blockList.members[i];

                if (block != null &&
                    FlxG.mouse.overlaps(block))
                {
                    addWorkspaceBlock(availableBlocks[i]);
                    clickedUI = true;
                    break;
                }
            }

            if (clickedUI)
                return;

            // WORKSPACE
            for (i in 0...workspaceBlocks.length)
            {
                var block = workspaceBlocks.members[i];

                if (block != null &&
                    FlxG.mouse.overlaps(block))
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
        }

        // DRAGGING
        if (dragging && dragIndex >= 0 &&
            dragIndex < workspaceBlocks.length)
        {
            var block = workspaceBlocks.members[dragIndex];
            var label = blockLabels.members[dragIndex];

            if (block != null && label != null)
            {
                if (FlxG.mouse.pressed)
                {
                    block.x = FlxG.mouse.x - dragOffsetX;
                    block.y = FlxG.mouse.y - dragOffsetY;

                    label.x = block.x + 9;
                    label.y = block.y + 11;

                    updateProperties();
                }
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
