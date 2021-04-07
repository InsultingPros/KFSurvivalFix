// Zombie Monster for KF Invasion gametype
class ZombiePat extends KFChar.ZombieBoss_STANDARD;

simulated function PostBeginPlay()
{
    super.PostBeginPlay();

	if( Level.NetMode!=NM_DedicatedServer )
	{
		SetBoneScale(3,0,'Syrange1');
		SetBoneScale(4,0,'Syrange2');
		SetBoneScale(5,0,'Syrange3');
	}
}
function Died(Controller Killer, class<DamageType> damageType, vector HitLocation)
{
    super(KFMonster).Died(Killer,damageType,HitLocation);
}

defaultproperties
{
     SyringeCount=3
     ClientSyrCount=3
     HealthMax=2000.000000
     Health=2000
     LODBias=4.500000
}
