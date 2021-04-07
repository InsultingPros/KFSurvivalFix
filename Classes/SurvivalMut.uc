class SurvivalMut extends Mutator
	CacheExempt;

var KFSurvival KFG;
var KFMonster KFM;
var bool bInitBoss;

function PreBeginPlay()
{
	KFG = KFSurvival(Level.Game);
	if( KFG==None )
		Error("This mutator is only for survival!");
}
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	if( Controller(Other)!=None )
		Controller(Other).PlayerReplicationInfoClass = Class'SurvPRI';
	else if( Other.Class==KFG.NextBossClass && KFG.bHadHugeWave )
	{
		bInitBoss = true;
		KFG.NextBossClass = None;
		if( KFG.bSuperBossMode )
		{
			KFM = KFMonster(Other);
			SetTimer(0.01,false);
		}
	}
	return true;
}
function Timer()
{
	if( KFM!=None && bInitBoss )
	{
		KFM.Health = FClamp(KFM.Health*10.f,1500.f,8000.f);
		KFM.HealthMax = KFM.Health;
		KFM.ScoringValue*=15.f;
		KFM.GroundSpeed*=3.f;
		KFM.OriginalGroundSpeed*=3.f;
		KFM.HeadHealth = FMax(KFM.HeadHealth,400)*35.f;
		KFM.SetDrawScale(KFM.DrawScale*1.2);
		KFM.MenuName = KFM.MenuName$" Boss";
		KFM.SetOverlayMaterial(TexOscillator'KFX.DeCloakOSC',99999.f,true);
	}
	bInitBoss = false;
}

defaultproperties
{
}
