#pragma header

uniform float hue;
uniform float saturation;
uniform float brightness;
uniform float contrast;

uniform float darkAmt;
uniform vec3 lightColor;
uniform float pulseStrength;
uniform float truckStrength;
uniform float isCharVal;
uniform float floorSkewU;

const vec3 grayscaleValues = vec3(0.3098039215686275, 0.607843137254902, 0.0823529411764706);
const float e = 2.718281828459045;

vec3 applyHueRotate(vec3 aColor, float aHue)
{
	float angle = radians(aHue);
	mat3 m1 = mat3(0.213, 0.213, 0.213, 0.715, 0.715, 0.715, 0.072, 0.072, 0.072);
	mat3 m2 = mat3(0.787, -0.213, -0.213, -0.715, 0.285, -0.715, -0.072, -0.072, 0.928);
	mat3 m3 = mat3(-0.213, 0.143, -0.787, -0.715, 0.140, 0.715, 0.928, -0.283, 0.072);
	mat3 m = m1 + cos(angle) * m2 + sin(angle) * m3;
	return m * aColor;
}

vec3 applySaturation(vec3 aColor, float value)
{
	if (value > 0.0) { value = value * 3.0; }
	value = (1.0 + (value / 100.0));
	vec3 grayscale = vec3(dot(aColor, grayscaleValues));
	return clamp(mix(grayscale, aColor, value), 0.0, 1.0);
}

vec3 applyContrast(vec3 aColor, float value)
{
	value = (1.0 + (value / 100.0));
	if (value > 1.0)
	{
		value = (((0.00852259 * pow(e, 4.76454 * (value - 1.0))) * 1.01) - 0.0086078159) * 10.0;
		value += 1.0;
	}
	return clamp((aColor - 0.25) * value + 0.25, 0.0, 1.0);
}

vec3 applyHSBCEffect(vec3 color)
{
	color = color + (brightness / 255.0);
	color = applyHueRotate(color, hue);
	color = applyContrast(color, contrast);
	color = applySaturation(color, saturation);
	return color;
}

vec3 hue2rgb(float h)
{
	h = fract(h);
	return clamp(vec3(
		abs(h * 6.0 - 3.0) - 1.0,
		2.0 - abs(h * 6.0 - 2.0),
		2.0 - abs(h * 6.0 - 4.0)
	), 0.0, 1.0);
}

vec3 rgb2hsl(vec3 c)
{
	float cMin = min(min(c.r, c.g), c.b);
	float cMax = max(max(c.r, c.g), c.b);
	float delta = cMax - cMin;
	vec3 hsl = vec3(0.0, 0.0, (cMax + cMin) / 2.0);
	if (delta != 0.0)
	{
		if (hsl.z < 0.5)
			hsl.y = delta / (cMax + cMin);
		else
			hsl.y = delta / (2.0 - cMax - cMin);

		float deltaR = (((cMax - c.r) / 6.0) + (delta / 2.0)) / delta;
		float deltaG = (((cMax - c.g) / 6.0) + (delta / 2.0)) / delta;
		float deltaB = (((cMax - c.b) / 6.0) + (delta / 2.0)) / delta;

		if (c.r == cMax)
			hsl.x = deltaB - deltaG;
		else if (c.g == cMax)
			hsl.x = (1.0 / 3.0) + deltaR - deltaB;
		else
			hsl.x = (2.0 / 3.0) + deltaG - deltaR;

		hsl.x = fract(hsl.x);
	}
	return hsl;
}

vec3 hsl2rgb(vec3 hsl)
{
	if (hsl.y == 0.0)
	{
		return vec3(hsl.z);
	}
	else
	{
		float b;
		if (hsl.z < 0.5)
			b = hsl.z * (1.0 + hsl.y);
		else
			b = hsl.z + hsl.y - hsl.y * hsl.z;
		float a = 2.0 * hsl.z - b;
		return a + hue2rgb(hsl.x) * (b - a);
	}
}

const float lightMultiplier = 0.07;

void main()
{
	vec2 uv = openfl_TextureCoordv;
	uv.x = uv.x + floorSkewU * (uv.y - 0.5);
	if (uv.x < 0.0 || uv.x > 1.0)
	{
		gl_FragColor = vec4(0.0);
		return;
	}

	vec4 col = flixel_texture2D(bitmap, uv);
	if (col.a <= 0.001)
	{
		gl_FragColor = vec4(0.0);
		return;
	}
	if (hue == 0.0 && saturation == 0.0 && brightness == 0.0 && contrast == 0.0 && darkAmt == 0.0 && pulseStrength == 0.0 && truckStrength == 0.0)
	{
		gl_FragColor = col;
		return;
	}

	vec3 unpremultipliedColor = col.rgb / col.a;
	vec3 outColor = applyHSBCEffect(unpremultipliedColor);

	float combinedAlpha = truckStrength + pulseStrength;
	float darkFactor = (combinedAlpha * lightMultiplier) + darkAmt;
	if (darkAmt > 0.65)
		darkFactor = (combinedAlpha * (-1.0 * lightMultiplier)) + darkAmt;

	vec3 bruhColor = rgb2hsl(lightColor);
	bruhColor.b = bruhColor.b * pulseStrength;
	bruhColor = hsl2rgb(bruhColor);

	vec3 multiplyColor = mix(vec3(1.0), vec3(0.0), clamp(darkFactor, 0.0, 1.0));
	multiplyColor = mix(multiplyColor, bruhColor, clamp(darkFactor / 2.0, 0.0, 1.0));

	outColor *= multiplyColor;
	gl_FragColor = vec4(outColor.rgb * col.a, col.a);
}
