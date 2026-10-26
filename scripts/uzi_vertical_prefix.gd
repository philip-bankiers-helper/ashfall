extends RefCounted
## 070 observed wall-endpoint pitch envelope, not intrinsic recoil or reticle bounce.
## Frozen left fit; independent right validation. Time is relative visible arrival.
## Beyond DURATION caller uses authored translated baseline growth, not extrapolation.
const DURATION:=0.8332700000000841
const END_PITCH:=8.637747438358025
const KNOTS:Array[Vector2]=[
 Vector2(0.0,0.0),Vector2(0.16665000000011787,1.8201427892660096),
 Vector2(0.33330500000010943,3.8132989949092746),Vector2(0.499960000000101,5.46675995465702),
 Vector2(0.6666100000001052,7.239650449370993),Vector2(DURATION,END_PITCH)]
static func pitch_degrees(t:float)->float:
 if t<=0.0:return 0.0
 for i in range(1,KNOTS.size()):
  if t<=KNOTS[i].x:return lerpf(KNOTS[i-1].y,KNOTS[i].y,(t-KNOTS[i-1].x)/(KNOTS[i].x-KNOTS[i-1].x))
 return END_PITCH
