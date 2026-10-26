extends RefCounted
## Original short metal latch and breakup transients, synthesized once on CPU.
static var _place:AudioStreamWAV
static var _break:AudioStreamWAV
static func stream(breaking:bool=false)->AudioStreamWAV:
	if breaking and _break!=null:return _break
	if not breaking and _place!=null:return _place
	var sample_rate:=22050
	var duration:=.24 if breaking else .17
	var bytes:=PackedByteArray();bytes.resize(int(duration*sample_rate)*2)
	var seed_value:=73061
	for index in bytes.size()/2:
		var t:=float(index)/sample_rate
		seed_value=(seed_value*1103515245+12345)&0x7fffffff
		var noise:=float(seed_value%65536)/32768.0-1.0
		var attack:=minf(t/.002,1.0)
		var signal_value:=0.0
		if breaking:
			signal_value=noise*exp(-t*21)*.54+sin(TAU*164*t)*exp(-t*28)*.22
		else:
			signal_value=noise*exp(-t*64)*.38+(sin(TAU*238*t)+sin(TAU*731*t)*.35)*exp(-t*31)*.28
		bytes.encode_s16(index*2,int(clampf(signal_value*attack,-.95,.95)*32767))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=sample_rate;wav.data=bytes
	if breaking:_break=wav
	else:_place=wav
	return wav
