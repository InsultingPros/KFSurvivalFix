Class SurvivalHUDOverlay extends HudOverlay;

var class<KFMonster> WaveMonsters[10];
var HUD InitializedHUD;
var localized string InfoText;

var bool bDisplayInfo;

replication
{
	reliable if ( Role==ROLE_Authority )
		bDisplayInfo,WaveMonsters;
}

final function Cleanup()
{
	local byte i;

	bDisplayInfo = false;
	for( i=0; i<ArrayCount(WaveMonsters); ++i )
		WaveMonsters[i] = None;
	NetUpdateTime = Level.TimeSeconds-1;
}
final function AddMonster( class<KFMonster> MC )
{
	local byte i;
	
	for( i=0; i<ArrayCount(WaveMonsters); ++i )
	{
		if( WaveMonsters[i]==None )
		{
			WaveMonsters[i] = MC;
			break;
		}
		else if( WaveMonsters[i]==MC )
			return;
	}
	NetUpdateTime = Level.TimeSeconds-1;
}
simulated function Tick( float Delta )
{
	local PlayerController PC;

	if( Level.NetMode==NM_DedicatedServer || InitializedHUD!=None )
	{
		Disable('Tick');
		return;
	}
	PC = Level.GetLocalPlayerController();
	if( PC==None || PC.myHUD==None )
		return;
	InitializedHUD = PC.myHUD;
	PC.myHUD.Overlays[PC.myHUD.Overlays.length] = Self;
	Disable('Tick');
}

simulated function Render(Canvas C)
{
	if( bDisplayInfo && !InitializedHUD.bShowScoreBoard )
		DrawActualInfo(C);
}
simulated final function DrawActualInfo( Canvas C )
{
	local byte S,i;
	local float XL,YL,YPos;

	S = C.Style;
	C.Style = ERenderStyle.STY_Alpha;
	C.Font = InitializedHUD.LoadFont(2);
	C.SetDrawColor(255,128,32,200);
	C.TextSize("ABC",XL,YL);
	
	YPos = C.ClipY*0.2f;
	C.SetPos(15,YPos-YL);
	C.DrawText(InfoText,false);
	for( i=0; (i<ArrayCount(WaveMonsters) && WaveMonsters[i]!=None); ++i )
	{
		C.SetPos(20,YPos+YL*i);
		C.DrawText(WaveMonsters[i].Default.MenuName,false);
	}
}

simulated function Destroyed()
{
	if( InitializedHUD!=None )
	{
		InitializedHUD.RemoveHudOverlay(self);
		InitializedHUD = None;
	}
}

defaultproperties
{
     InfoText="Upcoming wave:"
     bAlwaysRelevant=True
     bSkipActorPropertyReplication=True
     bOnlyDirtyReplication=True
     RemoteRole=ROLE_SimulatedProxy
     NetUpdateFrequency=0.250000
}
