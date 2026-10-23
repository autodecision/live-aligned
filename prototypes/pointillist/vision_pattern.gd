extends RefCounted

# Bake the expensive optical-art folds once, rather than evaluating trigonometry
# for every screen pixel on every frame. No source image or cache file is needed.
const SIZE := 512

static func create_texture() -> ImageTexture:
    var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
    for y in SIZE:
        var py := (float(y) + 0.5) * 2.0 / float(SIZE) - 1.0
        for x in SIZE:
            var px := (float(x) + 0.5) * 2.0 / float(SIZE) - 1.0
            var radius := sqrt(px * px + py * py)
            var angle := atan2(py, px)
            var fold := sin(angle * 11.0)
            var phase := ((radius + fold * 0.011) * 139.0
                + 0.65 * sin((px + py) * 36.0))
            var etching := sin(px * 360.0 - py * 410.0 + phase * 0.28)
            image.set_pixel(x, y, Color(
                0.5 + 0.5 * sin(phase),
                0.5 + 0.5 * cos(phase),
                0.5 + 0.5 * etching,
                0.5 + 0.5 * fold
            ))
    return ImageTexture.create_from_image(image)
