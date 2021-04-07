class GigaFleshPoundRange extends ZombieFleshPoundRange;

function FireMGShot()
{
	local vector Start,End,HL,HN,Dir;
	local rotator R;
	local Actor A;

	Start = GetBoneCoords('CHR_L_Blade3').Origin;
	if( Controller.Focus!=None )
		R = rotator(Controller.Focus.Location-Start);
	else R = rotator(Controller.FocalPoint-Start);
	Dir = Normal(vector(R)+VRand()*0.04);
	End = Start+Dir*10000;
	// Have to turn of hit point collision so trace doesn't hit the Human Pawn's bullet whiz cylinder
	bBlockHitPointTraces = false;
	A = Trace(HL,HN,End,Start,True);
	bBlockHitPointTraces = true;
	if( A==None )
		Return;
	TraceHitPos = HL;
	if( Level.NetMode!=NM_DedicatedServer )
		AddTraceHitFX(HL);
	if( A!=Level )
		A.TakeDamage(3+Rand(3),Self,HL,Dir*100,Class'DamageType');
}

defaultproperties
{
     Intelligence=BRAINS_Stupid
     HeadHealth=2000.000000
     ScoringValue=500
     HealthMax=3000.000000
     Health=3000
     MenuName="Giga Flesh Pound Chaingunner"
     Skins(0)=Texture'22CharTex.GibletsSkin'
}
