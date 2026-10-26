extends RefCounted
## Original warning tone and countdown rhythm; no sampled reference audio.
## The countdown begins at throw for frags and at impact for zone grenades.
const TONE_SECONDS:=.065
static var _tones:Dictionary={}

static func beat_times(duration:float)->PackedFloat32Array:
	var times:=PackedFloat32Array()
	if not is_finite(duration) or duration<=.18:return times
	# A power curve packs each later beat more closely. Keep the final
	# tone clear of the detonation/activation transient, with no tone after it.
	var end:=duration-.09
	var count:=maxi(3,int(ceil(duration*3.2)))
	for i in range(count):
		var phase:=float(i)/float(count-1)
		times.append(.09+(end-.09)*(1.0-pow(1.0-phase,1.65)))
	return times

static func tone(kind:String)->AudioStreamWAV:
	var key:="zone" if kind=="zone" else "frag"
	if _tones.has(key):return _tones[key]
	var rate:=24000
	var count:=int(TONE_SECONDS*rate)
	var bytes:=PackedByteArray();bytes.resize(count*2)
	var frequency:=1570.0 if key=="zone" else 1210.0
	for i in count:
		var time:=float(i)/rate
		var envelope:=minf(1.0,time/.004)*minf(1.0,(TONE_SECONDS-time)/.012)
		var wave:=(sin(TAU*frequency*time)+.16*sin(TAU*frequency*2.0*time))*.45*envelope
		bytes.encode_s16(i*2,int(clampf(wave,-1.0,1.0)*32767.0))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.data=bytes
	_tones[key]=wav
	return wav
