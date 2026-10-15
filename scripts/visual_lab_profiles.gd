extends RefCounted
# Portable look format. Values are renderer-independent and contain no code.
const SCHEMA_VERSION := 1
const GROUPS := ["Color", "Light", "Atmosphere", "Lens", "Style"]
# key, label, group, default, min, max, step, help
const CONTROLS := [
 ["effect_mix","Screen effect mix","Color",1.,0.,1.,.01,"Blend the screen treatment with the original image. Lighting and fog have their own controls."],
 ["exposure","Exposure / EV","Color",0.,-2.,2.,.01,"Lift or lower the image in photographic stops."],
 ["contrast","Contrast","Color",1.,.6,1.6,.01,"Separation between light and dark."],
 ["saturation","Saturation","Color",1.,0.,1.8,.01,"Overall color strength; zero is monochrome."],
 ["vibrance","Vibrance","Color",0.,-.5,.8,.01,"Boost quieter colors while protecting saturated ones."],
 ["temperature","Temperature","Color",0.,-1.,1.,.01,"Cool blue to warm amber."],
 ["tint","Magenta / green tint","Color",0.,-1.,1.,.01,"Balance magenta and green in the grade."],
 ["shadow_tone","Teal shadows","Color",0.,-1.,1.,.01,"Color darker areas without strongly tinting highlights."],
 ["highlight_warmth","Warm highlights","Color",0.,-1.,1.,.01,"Split-tone the bright areas."],
 ["gamma","Midtone gamma","Color",1.,.65,1.5,.01,"Shape midtones independently of exposure."],
 ["shadow_lift","Shadow lift","Color",0.,0.,.25,.005,"Raise deep blacks for a softer film look."],
 ["highlight_rolloff","Highlight compression","Color",0.,0.,1.,.01,"Compress bright areas to soften the image."],
 ["sun_strength","Sun / moon intensity","Light",1.4,.1,3.,.02,"Scale daylight and nighttime moonlight without changing the clock."],
 ["ambient_fill","Ambient fill","Light",.6,.05,1.5,.01,"Actual indirect fill; reduce for deeper shadows."],
 ["sun_elevation","Peak sun elevation / degrees","Light",35.,8.,80.,1.,"Height of the sun at midday. The clock animates its elevation."],
 ["sun_azimuth","Noon sun direction / degrees","Light",30.,-180.,180.,1.,"Heading of the sun at noon; the clock moves it around the island."],
 ["sun_warmth","Sun warmth","Light",0.,-1.,1.,.01,"Tint the real light, separate from the screen grade."],
 ["bloom","Highlight bloom","Light",0.,0.,1.2,.01,"A lightweight halo around bright areas. Higher values can wash out stone."],
 ["bloom_radius","Bloom radius / pixels","Light",5.,1.,16.,.5,"Spread of the halo; only active when bloom is above zero."],
 ["bloom_threshold","Bloom threshold","Light",.72,.35,.95,.01,"Brightness at which the halo begins."],
 ["fog_density","Distance haze","Atmosphere",.001,0.,.04,.0002,"Actual scene fog density."],
 ["fog_warmth","Haze warmth","Atmosphere",0.,-1.,1.,.01,"Cool coastal haze to amber mist."],
 ["height_haze","Low mist density","Atmosphere",0.,0.,.2,.002,"Additional fog near the mist height."],
 ["fog_height","Mist height / meters","Atmosphere",2.,-8.,16.,.25,"Height of the low mist layer."],
 ["sky_warmth","Sky warmth","Atmosphere",0.,-1.,1.,.01,"Grade the actual sky colors."],
 ["sky_brightness","Sky brightness","Atmosphere",1.,.3,1.8,.01,"Energy of the procedural sky."],
 ["fov","Field of view / degrees","Lens",75.,45.,100.,1.,"The player camera's field of view."],
 ["sharpness","Detail sharpening","Lens",0.,0.,.8,.01,"Adds local detail; high values can reveal foliage shimmer."],
 ["vignette","Vignette","Lens",0.,0.,.8,.01,"Darken the image edges."],
 ["vignette_softness","Vignette softness","Lens",.65,.15,1.,.01,"Width of the vignette transition."],
 ["chromatic","Chromatic fringe / pixels","Lens",0.,0.,3.,.05,"Separate red and blue toward the image edges."],
 ["film_grain","Film grain","Lens",0.,0.,.2,.005,"Intentional moving film noise. Keep at zero for a clean image."],
 ["lens_distortion","Lens curvature","Lens",0.,-.2,.2,.005,"Barrel or pincushion curvature."],
 ["letterbox","Letterbox height","Lens",0.,0.,.18,.005,"Cinematic bars as a fraction of the image height."],
 ["posterize","Painted color bands","Style",0.,0.,1.,.01,"Blend in discrete color steps for a painted game look."],
 ["color_levels","Color steps","Style",16.,3.,32.,1.,"Number of levels when painted color bands are enabled."],
 ["outlines","Illustrated outlines","Style",0.,0.,1.,.01,"Color-edge illustration, including foliage details."],
 ["outline_width","Outline width / pixels","Style",1.,.5,3.,.25,"Width of the illustrated edges."],
 ["scanlines","Retro scanlines","Style",0.,0.,.4,.01,"Fixed screen lines for a retro monitor look."],
 ["bleach","Bleach bypass","Style",0.,0.,1.,.01,"Desaturated, contrasty silver-retention film treatment."]
]
const POST_KEYS := ["effect_mix","exposure","contrast","saturation","vibrance","temperature","tint","shadow_tone","highlight_warmth","gamma","shadow_lift","highlight_rolloff","bloom","bloom_radius","bloom_threshold","sharpness","vignette","vignette_softness","chromatic","film_grain","lens_distortion","letterbox","posterize","color_levels","outlines","outline_width","scanlines","bleach"]
const PRESETS := [
 {"id":"original","name":"Original Mediterranean","inspiration":"Original scene","description":"The current coastal scene. A clean reference for comparing every change.","values":{}},
 {"id":"warframe","name":"Void light","inspiration":"Warframe","description":"Cool teal shadows, luminous highlights, vivid color and a crisp science-fiction finish.","values":{"contrast":1.12,"vibrance":.22,"temperature":-.15,"shadow_tone":.42,"highlight_warmth":.14,"bloom":.25,"bloom_radius":7.,"vignette":.16,"sharpness":.12}},
 {"id":"hyrule","name":"Painted daylight","inspiration":"Zelda: Breath of the Wild","description":"Warm, airy daylight with lifted shadows, rich greens and gentle painted color steps.","values":{"exposure":.06,"contrast":.94,"saturation":1.13,"vibrance":.15,"temperature":.2,"shadow_lift":.025,"highlight_rolloff":.2,"ambient_fill":.76,"posterize":.18,"color_levels":20.,"outlines":.06,"bloom":.08}},
 {"id":"witcher","name":"Golden wilderness","inspiration":"The Witcher 3","description":"Amber sunlight, cooler shadow color, soft haze and a grounded fantasy palette.","values":{"contrast":1.12,"saturation":.94,"temperature":.25,"shadow_tone":.2,"highlight_warmth":.35,"sun_elevation":24.,"sun_warmth":.38,"fog_density":.0024,"fog_warmth":.15,"vignette":.15,"bloom":.09}},
 {"id":"control","name":"Brutalist laboratory","inspiration":"Control","description":"Cool architectural light, restrained color, deep blacks and luminous equipment.","values":{"exposure":-.12,"contrast":1.23,"saturation":.75,"temperature":-.22,"shadow_tone":.38,"ambient_fill":.42,"bloom":.18,"bloom_threshold":.77,"vignette":.25,"sharpness":.08}},
 {"id":"alien","name":"Analog isolation","inspiration":"Alien: Isolation","description":"A muted green-cyan monitor look with optional analog grain, scanlines and lens fringe.","values":{"exposure":-.18,"contrast":1.15,"saturation":.7,"temperature":-.12,"tint":-.16,"shadow_tone":.25,"vignette":.34,"chromatic":.65,"film_grain":.025,"scanlines":.07,"lens_distortion":.025,"bleach":.12}},
 {"id":"red_dead","name":"Frontier sunset","inspiration":"Red Dead Redemption 2","description":"Low golden light, warm haze, soft highlight rolloff and a cinematic frame.","values":{"contrast":1.08,"saturation":.89,"temperature":.3,"highlight_warmth":.45,"sun_elevation":17.,"sun_warmth":.48,"ambient_fill":.52,"fog_density":.0028,"fog_warmth":.45,"sky_warmth":.32,"bloom":.12,"highlight_rolloff":.3,"vignette":.2,"letterbox":.055}}
]

static func defaults() -> Dictionary:
 var result:={}
 for control in CONTROLS:result[control[0]]=float(control[3])
 return result

static func preset_values(index:int)->Dictionary:
 var result:=defaults()
 result.merge(PRESETS[index].values,true)
 return result

static func validate(document:Variant)->Dictionary:
 if not document is Dictionary:return {"ok":false,"error":"This file is not a look profile."}
 if document.get("schema_version")!=SCHEMA_VERSION:return {"ok":false,"error":"Unsupported look version. Expected version 1."}
 if not document.get("parameters") is Dictionary:return {"ok":false,"error":"The profile has no parameter map."}
 if not document.get("profile_name") is String or document.profile_name.strip_edges().is_empty():return {"ok":false,"error":"The profile needs a name."}
 if document.has("effects_enabled") and not document.effects_enabled is bool:return {"ok":false,"error":"Effects enabled must be true or false."}
 var clean:=defaults()
 for control in CONTROLS:
  var key:String=control[0]
  if not document.parameters.has(key):continue
  var value:Variant=document.parameters[key]
  if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):
   return {"ok":false,"error":"Invalid numeric value for "+key+"."}
  clean[key]=clampf(float(value),float(control[4]),float(control[5]))
 return {"ok":true,"values":clean,"enabled":document.get("effects_enabled",true)}

static func file_slug(label:String)->String:
 var regex:=RegEx.new();regex.compile("[^a-z0-9_-]+")
 var slug:=regex.sub(label.strip_edges().to_lower(),"_",true).trim_prefix("_").trim_suffix("_").left(64)
 return slug if not slug.is_empty() else "my_look"
