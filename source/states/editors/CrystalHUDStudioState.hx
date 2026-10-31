
package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import lime.system.Clipboard;

class CrystalHUDStudioState extends MusicBeatState
{
    // INTERFAZ
    var bg:FlxSprite;
    var workspace:FlxSprite;
    var preview:FlxSprite;
    var properties:FlxSprite;

    var titleText:FlxText;
    var categoryText:FlxText;
    var previewText:FlxText;

    // GRUPOS
    var toolbox:FlxTypedGroup<FlxText>;
    var workspaceBlocks:FlxTypedGroup<FlxSprite>;
    var blockLabels:FlxTypedGroup<FlxText>;

    // DATOS
    var categories:Array<String> = [
        "Events",
        "Objects",
        "Properties",
        "Animations",
        "Logic",
        "Variables",
        "Game Data"
    ];

    var currentCategory:Int = 0;

    var blockTypes:Array<String> = [];
    var blockNames:Array<String> = [];

    var draggingBlock:FlxSprite = null;
    var dragOffsetX:Float = 0;
    var dragOffsetY:Float = 0;

    var showCode:Bool = false;
    var codeText:FlxText;

    var selectedColor:FlxColor = 0xFF873BFF;

    override function create()
    {
        super.create();

        FlxG.camera.bgColor = 0xFF08070C;
        FlxG.mouse.visible = true;

        // FONDO
        bg = new FlxSprite().makeGraphic(
            FlxG.width,
            FlxG.height,
            0xFF08070C
        );
        add(bg);

        createInterface();
        createToolbox();
        createWorkspace();

        #if mobile
        add(mobile.MobileButton.back());
        #end
    }

    function createInterface()
    {
        var top = new FlxSprite(0, 0).makeGraphic(
            FlxG.width, 55, 0xFF111018
        );
        add(top);

        var line = new FlxSprite(0, 54).makeGraphic(
            FlxG.width, 2, 0xFF913EFF
        );
        add(line);

        titleText = new FlxText(18, 12, 350,
            "CRYSTAL HUD STUDIO", 24);
        titleText.setFormat(
            null, 24, FlxColor.WHITE, LEFT,
            FlxTextBorderStyle.NONE
        );
        add(titleText);

        var exportButton = new FlxSprite(
            FlxG.width - 160, 9
        ).makeGraphic(140, 38, 0xFF6124A8);
        add(exportButton);

        var exportLabel = new FlxText(
            FlxG.width - 155, 17, 130,
            "EXPORT LUA", 16
        );
        exportLabel.alignment = CENTER;
        exportLabel.color = FlxColor.WHITE;
        add(exportLabel);
    }

    function createToolbox()
    {
        var panel = new FlxSprite(0, 56).makeGraphic(
            190, FlxG.height - 56, 0xFF111018
        );
        add(panel);

        var heading = new FlxText(
            12, 70, 170, "CATEGORIES", 17
        );
        heading.color = 0xFFB879FF;
        add(heading);

        toolbox = new FlxTypedGroup<FlxText>();
        add(toolbox);

        for (i in 0...categories.length)
        {
            var item = new FlxText(
                12, 110 + i * 43, 170,
                categories[i], 17
            );

            item.color = FlxColor.WHITE;
            item.ID = i;

            toolbox.add(item);
        }

        categoryText = new FlxText(
            205, 70, 300, "EVENTS", 20
        );
        categoryText.color = 0xFFB879FF;
        add(categoryText);
    }

    function createWorkspace()
    {
        // ESPACIO DE BLOQUES
        workspace = new FlxSprite(
            190, 100
        ).makeGraphic(
            Std.int(FlxG.width * 0.47),
            FlxG.height - 100,
            0xFF17151D
        );
        add(workspace);

        var workspaceTitle = new FlxText(
            205, 110, 300, "WORKSPACE", 17
        );
        workspaceTitle.color = 0xFFB879FF;
        add(workspaceTitle);

        workspaceBlocks = new FlxTypedGroup<FlxSprite>();
        add(workspaceBlocks);

        blockLabels = new FlxTypedGroup<FlxText>();
        add(blockLabels);

        // VISTA PREVIA
        var previewX = Std.int(FlxG.width * 0.68);

        preview = new FlxSprite(
            previewX, 100
        ).makeGraphic(
            FlxG.width - previewX - 10,
            Std.int(FlxG.height * 0.48),
            0xFF000000
        );
        add(preview);

        var previewTitle = new FlxText(
            previewX + 10, 110,
            250, "HUD PREVIEW", 17
        );
        previewTitle.color = 0xFFB879FF;
        add(previewTitle);

        previewText = new FlxText(
            previewX + 20, 170,
            FlxG.width - previewX - 40,
            "HUD Preview", 22
        );
        previewText.alignment = CENTER;
        previewText.color = FlxColor.WHITE;
        add(previewText);

        // PROPIEDADES
        properties = new FlxSprite(
            previewX,
            Std.int(FlxG.height * 0.60)
        ).makeGraphic(
            FlxG.width - previewX - 10,
            Std.int(FlxG.height * 0.38),
            0xFF111018
        );
        add(properties);

        var propertyTitle = new FlxText(
            previewX + 10,
            properties.y + 10,
            250,
            "PROPERTIES", 17
        );
        propertyTitle.color = 0xFFB879FF;
        add(propertyTitle);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        // SELECCIONAR CATEGORIA
        for (item in toolbox.members)
        {
            if (item != null &&
                FlxG.mouse.justPressed &&
                FlxG.mouse.overlaps(item))
            {
                currentCategory = item.ID;
                changeCategory();
            }
        }

        // ARRASTRAR BLOQUES
        if (draggingBlock != null)
        {
            if (FlxG.mouse.pressed)
            {
                draggingBlock.x = FlxG.mouse.x - dragOffsetX;
                draggingBlock.y = FlxG.mouse.y - dragOffsetY;
            }

            if (FlxG.mouse.justReleased)
            {
                draggingBlock = null;
            }
        }
        else if (FlxG.mouse.justPressed)
        {
            for (block in workspaceBlocks.members)
            {
                if (block != null && FlxG.mouse.overlaps(block))
                {
                    draggingBlock = block;

                    dragOffsetX = FlxG.mouse.x - block.x;
                    dragOffsetY = FlxG.mouse.y - block.y;
                    break;
                }
            }
        }

        // EXPORTAR
        if (FlxG.keys.justPressed.ESCAPE)
        {
            if (showCode)
                hideCode();
        }

        if (controls.BACK)
        {
            MusicBeatState.switchState(
                new MasterEditorMenu()
            );
        }
    }

    function changeCategory()
    {
        categoryText.text = categories[currentCategory].toUpperCase();

        switch(currentCategory)
        {
            case 0:
                loadBlocks([
                    "When song starts",
                    "When step hits",
                    "When beat hits",
                    "When song ends"
                ]);

            case 1:
                loadBlocks([
                    "Create text",
                    "Create sprite",
                    "Remove object",
                    "Add to HUD"
                ]);

            case 2:
                loadBlocks([
                    "Set position",
                    "Set scale",
                    "Set alpha",
                    "Set visibility"
                ]);

            case 3:
                loadBlocks([
                    "Tween X",
                    "Tween Y",
                    "Tween Alpha",
                    "Tween Scale"
                ]);

            case 4:
                loadBlocks([
                    "If",
                    "If / Else",
                    "Repeat",
                    "Forever"
                ]);

            case 5:
                loadBlocks([
                    "Set variable",
                    "Change variable",
                    "Get variable"
                ]);

            case 6:
                loadBlocks([
                    "Get score",
                    "Get combo",
                    "Get misses",
                    "Get health",
                    "Get song position"
                ]);
        }
    }

    function loadBlocks(names:Array<String>)
    {
        blockTypes = [];
        blockNames = names.copy();

        // Esta primera versión utiliza bloques
        // seleccionables para añadirlos al workspace.
    }

    function addBlock(name:String, type:String)
    {
        var block = new FlxSprite(
            215,
            150 + workspaceBlocks.length * 55
        );

        block.makeGraphic(220, 43, getBlockColor(type));
        workspaceBlocks.add(block);

        var label = new FlxText(
            block.x + 10,
            block.y + 11,
            200,
            name,
            15
        );

        label.color = FlxColor.WHITE;
        blockLabels.add(label);

        blockNames.push(name);
        blockTypes.push(type);
    }

    function getBlockColor(type:String):FlxColor
    {
        return switch(type)
        {
            case "Events": 0xFFE5B92E;
            case "Objects": 0xFF38A85C;
            case "Properties": 0xFF3995DB;
            case "Animations": 0xFFE89B32;
            case "Logic": 0xFF9A55D5;
            case "Variables": 0xFFE47732;
            default: 0xFF398DCB;
        }
    }

    function generateLua():String
    {
        var lua:String = "-- Generated by Crystal HUD Studio\n\n";

        for (name in blockNames)
        {
            switch(name)
            {
                case "When song starts":
                    lua += "function onCreatePost()\n";

                case "When step hits":
                    lua += "function onStepHit()\n";

                case "When beat hits":
                    lua += "function onBeatHit()\n";

                case "Create text":
                    lua += "makeLuaText('myText', 'Hello!', 200, 100, 100)\n";
                    lua += "addLuaText('myText')\n";

                case "Create sprite":
                    lua += "-- Configure your sprite here\n";

                case "Get score":
                    lua += "local currentScore = getProperty('songScore')\n";

                default:
                    lua += "-- " + name + "\n";
            }
        }

        return lua;
    }

    function showCodeWindow()
    {
        showCode = true;

        codeText = new FlxText(
            220, 120,
            FlxG.width - 440,
            generateLua(),
            16
        );

        codeText.color = FlxColor.WHITE;
        codeText.borderStyle = FlxTextBorderStyle.OUTLINE;
        codeText.borderColor = FlxColor.BLACK;

        add(codeText);
    }

    function hideCode()
    {
        showCode = false;

        if (codeText != null)
        {
            remove(codeText);
            codeText.destroy();
            codeText = null;
        }
    }
}
