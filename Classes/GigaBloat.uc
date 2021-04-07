// Zombie Monster for KF Invasion gametype
class GigaBloat extends KFChar.ZombieBloat_STANDARD;

function RangedAttack(Actor A)
{
	local int LastFireTime;
    local float ChargeChance;

	if ( bShotAnim )
		return;

	if ( Physics == PHYS_Swimming )
	{
		SetAnimAction('Claw');
		bShotAnim = true;
		LastFireTime = Level.TimeSeconds;
	}
	else if ( VSize(A.Location - Location) < MeleeRange + CollisionRadius + A.CollisionRadius )
	{
		bShotAnim = true;
		LastFireTime = Level.TimeSeconds;
		SetAnimAction('Claw');
		//PlaySound(sound'Claw2s', SLOT_Interact); KFTODO: Replace this
		Controller.bPreparingMove = true;
		Acceleration = vect(0,0,0);
	}
	else if ( (KFDoorMover(A) != none || VSize(A.Location-Location) <= 350) && !bDecapitated )
	{
		bShotAnim = true;

        // Decide what chance the bloat has of charging during a puke attack
        if( Level.Game.GameDifficulty < 2.0 )
            ChargeChance = 0.5;
        else if( Level.Game.GameDifficulty < 4.0 )
            ChargeChance = 0.7;
        else if( Level.Game.GameDifficulty < 5.0 )
            ChargeChance = 0.8;
        else // Hardest difficulty
            ChargeChance = 0.95;


		// Randomly do a moving attack so the player can't kite the zed
        if( FRand() < ChargeChance )
		{
    		SetAnimAction('ZombieBarfMoving');
    		RunAttackTimeout = GetAnimDuration('ZombieBarf', 1.0);
    		bMovingPukeAttack=true;
		}
		else
		{
    		SetAnimAction('ZombieBarf');
    		Controller.bPreparingMove = true;
    		Acceleration = vect(0,0,0);
		}


		// Randomly send out a message about Bloat Vomit burning(3% chance)
		if ( FRand() < 0.03 && KFHumanPawn(A) != none && PlayerController(KFHumanPawn(A).Controller) != none )
		{
			PlayerController(KFHumanPawn(A).Controller).Speech('AUTO', 7, "");
		}
	}
}

// Barf Time.
function SpawnTwoShots()
{
	local vector X,Y,Z, FireStart;
	local rotator FireRotation;

	if( Controller!=None && KFDoorMover(Controller.Target)!=None )
	{
		Controller.Target.TakeDamage(45,Self,Location,vect(0,0,0),Class'DamTypeVomit');
		return;
	}

	GetAxes(Rotation,X,Y,Z);
	FireStart = Location+(vect(30,0,64) >> Rotation)*DrawScale;
	if ( !SavedFireProperties.bInitialized )
	{
		SavedFireProperties.AmmoClass = Class'SkaarjAmmo';
		SavedFireProperties.ProjectileClass = Class'KFBloatVomitX';
		SavedFireProperties.WarnTargetPct = 1;
		SavedFireProperties.MaxRange = 500;
		SavedFireProperties.bTossed = False;
		SavedFireProperties.bTrySplash = False;
		SavedFireProperties.bLeadTarget = True;
		SavedFireProperties.bInstantHit = True;
		SavedFireProperties.bInitialized = True;
	}

    // Turn off extra collision before spawning vomit, otherwise spawn fails
    ToggleAuxCollision(false);
	FireRotation = Controller.AdjustAim(SavedFireProperties,FireStart,600);
	Spawn(Class'KFBloatVomitX',,,FireStart,FireRotation);

	FireStart-=(0.5*CollisionRadius*Y);
	FireRotation.Yaw -= 1200;
	spawn(Class'KFBloatVomitX',,,FireStart, FireRotation);

	FireStart+=(CollisionRadius*Y);
	FireRotation.Yaw += 2400;
	spawn(Class'KFBloatVomitX',,,FireStart, FireRotation);
	// Turn extra collision back on
	ToggleAuxCollision(true);
}

defaultproperties
{
     MeleeDamage=20
     HeadHealth=250.000000
     ScoringValue=25
     HealthMax=1500.000000
     Health=1500
     MenuName="Giga Bloat"
     Skins(0)=Texture'22CharTex.GibletsSkin'
}
