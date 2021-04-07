// Survival game mode, written by Marco.
class KFSurvival extends KFGameType
	config(KFSurvival);

var SurvGameStats SurvivalStats;

enum EGameStyle
{
	GS_Classic,
	GS_TimedWaves,
	GS_Continiuous,
	GS_Hardcore,
};
var() globalconfig byte GameStyle;
struct FMonsterInfoEntry
{
	var() config string MonsterClass;
	var() config float Difficulty,EndDifficulty,Count;
	var() config bool bSuperMonster;
	var transient class<KFMonster> MC;
};
var() globalconfig array<FMonsterInfoEntry> Monsters;
var() globalconfig float WaveDifficultyRamp,InitialDifficulty,BossesPerPlayer;
var() globalconfig int BossWaveInterval,MaxSquadsPerWave,MaxZedsPerSquad,StatsSaveWaves,MinSquadSize,MaxSquadSize,BossCount;
var() globalconfig array<string> BossClasses;
var float CurDifficultyLevel,NextForceSquadTime;
var class<KFMonster> NextBossClass,FullBossClass;
var SurvivalHUDOverlay SurvivalHUDRep;
var int HugeWaveMCount,BossMessageCounter,NumSpecimenLeft,WavesCounter,NumBossesLeft,HugeWaveSpawnsLeft;

var array<MSquadsList> NextInitSquads;

struct FTopPlayerEntry
{
	var string Player;
	var int Score;
};
var array<FTopPlayerEntry> TopPlayers;

var() globalconfig bool bHasHugeWaves,bHasWaveBosses,bTrackStats;
var bool bInitiatedWaveEnd,bHadHugeWave,bSuperBossMode,bSpawningMobs,bSafeRoomTime,bGotTopPlayers;

final function StatsCompleted()
{
	local Controller C;
	local PlayerController PC;
	local SurvPRI PRI;
	local int Res;

	bGotTopPlayers = true;
	TopPlayers.Length = Min(SurvivalStats.TopScores.Length,30);
	for( Res=0; Res<TopPlayers.Length; ++Res )
	{
		TopPlayers[Res].Player = SurvivalStats.PL[SurvivalStats.TopScores[Res]].N;
		TopPlayers[Res].Score = SurvivalStats.PL[SurvivalStats.TopScores[Res]].S;
	}
	
	for( C=Level.ControllerList; C!=None; C=C.nextController )
	{
		PC = PlayerController(C);
		if( PC!=None && PC.Player!=None && SurvPRI(PC.PlayerReplicationInfo)!=None )
		{
			PRI = SurvPRI(PC.PlayerReplicationInfo);
			Res = SurvivalStats.GetPlayerLevel(PC.GetPlayerIDHash(),PRI.PlayerName,PRI.PlayerIndex,PRI.PlayerRank);
			PRI.BestSurvivedWaves = Clamp(Res,0,255);
		}
	}
}

function GetServerInfo( out ServerResponseLine ServerState )
{
	ServerState.ServerName		= GameReplicationInfo.ServerName;
	ServerState.MapName			= string(Outer.Name);
	ServerState.GameType		= string('KFGameType');
	ServerState.CurrentPlayers	= NumPlayers;
	ServerState.MaxPlayers		= MaxPlayers;
	ServerState.IP				= ""; // filled in at the other end.
	ServerState.Port			= GetServerPort();
    ServerState.SkillLevel		= "1";
	ServerState.ServerInfo.Length = 0;
	ServerState.PlayerInfo.Length = 0;
}

function DoBossDeath(); // Nope.

function LoadUpMonsterList()
{
	local int i,j;
	local string S;
	local array<name> Pck;
	local Object O;

	CurDifficultyLevel = InitialDifficulty;
	for( i=0; i<Monsters.Length; i++ )
	{
		S = Monsters[i].MonsterClass;
		if( InStr(S,".")==-1 )
			S = string(Class.Outer.Name)$"."$S;
		Monsters[i].MC = Class<KFMonster>(DynamicLoadObject(S,Class'Class'));
		O = Monsters[i].MC;
		if( O!=None && Level.NetMode!=NM_StandAlone )
		{
			while( O.Outer!=None )
				O = O.Outer;
			if( O.Name==Class.Outer.Name || O.Name=='KFChar' )
				continue;
			for( j=(Pck.Length-1); j>=0; --j )
				if( Pck[j]==O.Name )
					break;
			if( j<0 )
				Pck[Pck.Length] = O.Name;
		}
	}
	if( Level.NetMode!=NM_StandAlone )
	{
		for( i=(BossClasses.Length-1); i>=0; --i )
		{
			S = BossClasses[i];
			if( Left(S,1)=="*" )
				S = Mid(S,1);
			O = DynamicLoadObject(S,Class'Class');
			if( O==None )
				continue;
			while( O.Outer!=None )
				O = O.Outer;
			if( O.Name==Class.Outer.Name || O.Name=='KFChar' )
				continue;
			for( j=(Pck.Length-1); j>=0; --j )
				if( Pck[j]==O.Name )
					break;
			if( j<0 )
				Pck[Pck.Length] = O.Name;
		}
		Log("Adding"@Pck.Length@"additional serverpackages for the monsters.",Class.Name);
		for( j=(Pck.Length-1); j>=0; --j )
			AddToPackageMap(string(Pck[j]));
	}
}
event PreBeginPlay()
{
	Super.PreBeginPlay();
	InvasionGameReplicationInfo(GameReplicationInfo).FinalWave = 0;
	if( SurvivalStats!=None )
		InvasionGameReplicationInfo(GameReplicationInfo).FinalWave = SurvivalStats.GetBestWaveNum();
	FinalWave = 12;
}
event InitGame( string Options, out string Error )
{
	local ShopVolume SH;
	local ZombieVolume ZZ;
	local string InOpt;
	local SlowStatLoader LL;

	// Take important global configures from parent class.
	bAllowBehindView = Class'GameInfo'.Default.bAllowBehindView;
	bAdminCanPause = Class'GameInfo'.Default.bAdminCanPause;
	bLargeGameVOIP = Class'GameInfo'.Default.bLargeGameVOIP;
	MaxSpectators = Class'GameInfo'.Default.MaxSpectators;
	MaxPlayers = Class'GameInfo'.Default.MaxPlayers;
	AccessControlClass = Class'GameInfo'.Default.AccessControlClass;
	MaplistHandlerType = Class'GameInfo'.Default.MaplistHandlerType;
	GameStatsClass = Class'GameInfo'.Default.GameStatsClass;
	SecurityClass = Class'GameInfo'.Default.SecurityClass;
	MaxIdleTime = Class'GameInfo'.Default.MaxIdleTime;
	bIgnore32PlayerLimit = Class'GameInfo'.Default.bIgnore32PlayerLimit;
	bVACSecured = Class'GameInfo'.Default.bVACSecured;
	VotingHandlerType = Class'GameInfo'.Default.VotingHandlerType;
	
	MutatorClass = string(Class'SurvivalMut');
	ScoreBoardType = string(Class'SurvScoreBoard');
	Super(Invasion).InitGame(Options, Error);

	foreach AllActors(class'KFLevelRules',KFLRules)
		break;
	foreach AllActors(class'ShopVolume',SH)
		ShopList[ShopList.Length] = SH;
	foreach AllActors(class'ZombieVolume',ZZ)
		ZedSpawnList[ZedSpawnList.Length] = ZZ;

	// provide default rules if mapper did not need custom one
	if(KFLRules==none)
		KFLRules = spawn(class'KFLevelRules');

	InOpt = ParseOption(Options, "UseBots");
	if ( InOpt != "" )
		bNoBots = bool(InOpt);
		
	InOpt = ParseOption(Options, "Style");
	if ( InOpt!="" )
	{
		switch( Caps(InOpt) )
		{
		case "0":
		case "CLASSIC":
			GameStyle = EGameStyle.GS_Classic;
			break;
		case "1":
		case "TIMEDWAVES":
			GameStyle = EGameStyle.GS_TimedWaves;
			break;
		case "2":
		case "CONTINIUOUS":
			GameStyle = EGameStyle.GS_Continiuous;
			break;
		case "3":
		case "HARDCORE":
			GameStyle = EGameStyle.GS_Hardcore;
			break;
		}
	}

	LoadUpMonsterList();
	SurvivalHUDRep = Spawn(Class'SurvivalHUDOverlay');
	InitNextWave();
	if( bTrackStats )
	{
		SurvivalStats = new (None,"Players") Class'SurvGameStats';
		SurvivalStats.InitStats(Outer.Name);
		
		LL = Spawn(Class'SlowStatLoader');
		LL.S = SurvivalStats;
	}
}
event PostLogin( PlayerController NewPlayer )
{
	local SurvPRI PRI;
	local int Res;

	Super.PostLogin(NewPlayer);
	if( SurvivalStats!=None )
	{
		PRI = SurvPRI(NewPlayer.PlayerReplicationInfo);
		PRI.ClientIDHash = NewPlayer.GetPlayerIDHash();
		Res = SurvivalStats.GetPlayerLevel(NewPlayer.GetPlayerIDHash(),PRI.PlayerName,PRI.PlayerIndex,PRI.PlayerRank);
		PRI.BestSurvivedWaves = Clamp(Res,0,255);
		
		if( !bGotTopPlayers )
		{
			bGotTopPlayers = true;
			TopPlayers.Length = Min(SurvivalStats.TopScores.Length,30);
			for( Res=0; Res<TopPlayers.Length; ++Res )
			{
				TopPlayers[Res].Player = SurvivalStats.PL[SurvivalStats.TopScores[Res]].N;
				TopPlayers[Res].Score = SurvivalStats.PL[SurvivalStats.TopScores[Res]].S;
			}
		}
	}
}
function Logout(Controller Exiting)
{
	local SurvPRI PRI;

	if( SurvivalStats!=None && PlayerController(Exiting)!=None && SurvPRI(Exiting.PlayerReplicationInfo)!=None )
	{
		PRI = SurvPRI(Exiting.PlayerReplicationInfo);
		if( PRI.BestSurvivedWaves>0 )
			SurvivalStats.SetPlayerLevel(PRI.ClientIDHash,PRI.PlayerName,PRI.BestSurvivedWaves,PRI.PlayerIndex);
	}
	super.Logout(Exiting);
}
function ProcessServerTravel( string URL, bool bItems )
{
	SaveAllStats();
	Super.ProcessServerTravel(URL,bItems);
}
final function SaveAllStats()
{
	local Controller C;
	local SurvPRI PRI;

	if( SurvivalStats==None )
		return;
	for( C=Level.ControllerList; C!=None; C=C.nextController )
	{
		if( !C.bIsPlayer )
			continue;
		PRI = SurvPRI(C.PlayerReplicationInfo);
		if( PRI!=None && PRI.BestSurvivedWaves>0 )
			SurvivalStats.SetPlayerLevel(PRI.ClientIDHash,PRI.PlayerName,PRI.BestSurvivedWaves,PRI.PlayerIndex);
	}
	SurvivalStats.SaveStats();
}
static function FillPlayInfo(PlayInfo PlayInfo)
{
	Super(Info).FillPlayInfo(PlayInfo);  // Always begin with calling parent

	PlayInfo.AddSetting(default.GameGroup,"GameDifficulty", GetDisplayText("GameDifficulty"),	0, 0, "Select", default.GIPropsExtras[0], "Xb");

	PlayInfo.AddSetting(default.SandboxGroup,"WaveStartSpawnPeriod", GetDisplayText("WaveStartSpawnPeriod"),50,5,"Text","3;0.0:6.0");
	PlayInfo.AddSetting(default.SandboxGroup,"StartingCash", GetDisplayText("StartingCash"),0,0,"Text","200;0:2000");
	PlayInfo.AddSetting(default.SandboxGroup,"MinRespawnCash", GetDisplayText("MinRespawnCash"),0,1,"Text","200;0:2000");

    PlayInfo.AddSetting(default.SandboxGroup,"TimeBetweenWaves", GetDisplayText("TimeBetweenWaves"),0,3,"Text","60;1:999");
	PlayInfo.AddSetting(default.SandboxGroup, "MaxZombiesOnce", GetDisplayText("MaxZombiesOnce"),70,2,"Text","4;6:600");

	PlayInfo.AddSetting(default.ServerGroup, "LobbyTimeOut",	GetDisplayText("LobbyTimeOut"),		0, 1, "Text",	"3;0:120",	,True,True);
	PlayInfo.AddSetting(default.ServerGroup, "bAdminCanPause",	GetDisplayText("bAdminCanPause"),	1, 1, "Check",			 ,	,True,True);
	PlayInfo.AddSetting(default.ServerGroup, "MaxSpectators",	GetDisplayText("MaxSpectators"),	1, 1, "Text",	 "6;0:32",	,True,True);
	PlayInfo.AddSetting(default.ServerGroup, "MaxPlayers",		GetDisplayText("MaxPlayers"),		0, 1, "Text",	  "6;1:6",	,True);
	PlayInfo.AddSetting(default.ServerGroup, "MaxIdleTime",		GetDisplayText("MaxIdleTime"),		0, 1, "Text",	"3;0:300",	,True,True);

	PlayInfo.AddSetting(default.SandboxGroup, "GameStyle", "Game Style",50,4,"Select","0;Classic;1;Timed Waves;2;Continiuous;3;Hardcore");

	// PlayInfo.AddSetting(default.SandboxGroup,"TmpWavesInf", GetDisplayText("TmpWavesInf"),80,8,"Custom",";;KFGui.KFInvWaveConfig",,,);

	// Add GRI's PIData
	if (default.GameReplicationInfoClass != None)
	{
		default.GameReplicationInfoClass.static.FillPlayInfo(PlayInfo);
		PlayInfo.PopClass();
	}

	if (default.VoiceReplicationInfoClass != None)
	{
		default.VoiceReplicationInfoClass.static.FillPlayInfo(PlayInfo);
		PlayInfo.PopClass();
	}

	if (default.BroadcastClass != None)
		default.BroadcastClass.static.FillPlayInfo(PlayInfo);
	else class'BroadcastHandler'.static.FillPlayInfo(PlayInfo);

	PlayInfo.PopClass();

	if (class'Engine.GameInfo'.default.VotingHandlerClass != None)
	{
		class'Engine.GameInfo'.default.VotingHandlerClass.static.FillPlayInfo(PlayInfo);
		PlayInfo.PopClass();
	}
	else
		log("GameInfo::FillPlayInfo class'Engine.GameInfo'.default.VotingHandlerClass = None");
}
static event string GetDescriptionText(string PropName)
{
	switch (PropName)
	{
		case "GameStyle":		return "Gameplay style.";
	}
	return Super.GetDescriptionText(PropName);
}

function StartInitGameMusic( KFPlayerController Other )
{
	local string S;
	local int i;

	if( MapSongHandler==None )
		Return;
	i = MapSongHandler.WaveBasedSongs.Length;
	if( MusicPlaying )
	{
		if( i==0 || MapSongHandler.WaveBasedSongs[WaveNum % i].CombatSong=="" )
			S = MapSongHandler.CombatSong;
		else S = MapSongHandler.WaveBasedSongs[WaveNum % i].CombatSong;
	}
	else if( CalmMusicPlaying )
	{
		if( i==0 || MapSongHandler.WaveBasedSongs[WaveNum % i].CalmSong=="" )
			S = MapSongHandler.Song;
		else S = MapSongHandler.WaveBasedSongs[WaveNum % i].CalmSong;
	}
	if( S!="" )
		Other.NetPlayMusic(S,0.5,0);
}
function StartGameMusic( bool bCombat )
{
	local Controller C;
	local string S;
	local int i;

	if( MapSongHandler==None )
		Return;
	i = MapSongHandler.WaveBasedSongs.Length;
	if( bCombat )
	{
		if( i==0 || MapSongHandler.WaveBasedSongs[WaveNum % i].CombatSong=="" )
			S = MapSongHandler.CombatSong;
		else S = MapSongHandler.WaveBasedSongs[WaveNum % i].CombatSong;
		MusicPlaying = True;
		CalmMusicPlaying = False;
	}
	else
	{
		if( i==0 || MapSongHandler.WaveBasedSongs[WaveNum % i].CalmSong=="" )
			S = MapSongHandler.Song;
		else S = MapSongHandler.WaveBasedSongs[WaveNum % i].CalmSong;
		CalmMusicPlaying = True;
		MusicPlaying = False;
	}

	for( C=Level.ControllerList;C!=None;C=C.NextController )
	{
		if (KFPlayerController(C)!= none)
			KFPlayerController(C).NetPlayMusic(S,MapSongHandler.FadeInTime,MapSongHandler.FadeOutTime);
	}
}

exec function SetWave( int WN )
{
	if( SurvivalStats!=None ) // Admin used a cheat, disable stats for now.
	{
		SaveAllStats();
		SurvivalStats = None;
	}
	WaveNum = WN;
	CurDifficultyLevel = InitialDifficulty+float(WN)*WaveDifficultyRamp;
	if( !bWaveInProgress )
	{
		SetupWave();
		bWaveInProgress = true;
	}
	bHadHugeWave = true;
	TotalMaxMonsters = 0;
	WaveEndTime = 0;
	bInitiatedWaveEnd = true;
}
final function float GetGigaDesire( float DesireDiff )
{
	if( DesireDiff>0.6f ) // Start to ramp down again...
		DesireDiff = 2.f/((DesireDiff*3.f)-0.8f);
	else DesireDiff*=3.33f;
	return (DesireDiff*(3.f+FRand()));
}
final function float GetMonsterDesire( float StartDif, float EndDif )
{
	if( CurDifficultyLevel<EndDif )
		StartDif = FMin(CurDifficultyLevel-StartDif,1.f);
	else StartDif = (1.f/(CurDifficultyLevel-EndDif+1.f))*0.9 + 0.1f;
	return StartDif*(0.8+FRand()*0.6);
}
final function InitNextWave()
{
	local int i,j,z,iGiga;
	local float NumPerSquad,NumPlayersMod,MinDesire;
	local array< class<KFMonster> > MA;
	local array<int> MS;
	local class<KFMonster> GigaMonsterClass;
	local bool bGigaFound;

	// Select a giga monster class
	iGiga = -1;
	if( FRand()<0.5 )
	{
		for( i=(Monsters.Length-1); i>=0; --i )
		{
			if( Monsters[i].MC!=None && Monsters[i].bSuperMonster && CurDifficultyLevel>Monsters[i].Difficulty )
			{
				NumPlayersMod = GetGigaDesire(CurDifficultyLevel-Monsters[i].Difficulty);
				if( iGiga==-1 || NumPlayersMod>MinDesire )
				{
					iGiga = i;
					MinDesire = NumPlayersMod;
				}
			}
		}
		if( iGiga>=0 )
		{
			GigaMonsterClass = Monsters[iGiga].MC;
			MS[MS.Length] = iGiga;
		}
	}

	// First lookup a list of possible monster types.
	for( i=(Monsters.Length-1); i>=0; --i )
	{
		if( Monsters[i].MC!=None && !Monsters[i].bSuperMonster && CurDifficultyLevel>Monsters[i].Difficulty )
			MS[MS.Length] = i;
	}
	
	// Then reduce list size
	i = 5+Rand(5);
	while( MS.Length>i )
	{
		j = Rand(MS.Length);
		if( MS[j]!=iGiga )
			MS.Remove(j,1);
	}
	
	// Now build up a list of monsters.
	for( i=(MS.Length-1); i>=0; --i )
	{
		MinDesire = GetMonsterDesire(Monsters[MS[i]].Difficulty,Monsters[MS[i]].EndDifficulty)*Monsters[MS[i]].Count;
		if( MS[i]==iGiga )
			j = Clamp(MinDesire,1,2+Rand(2));
		else j = Clamp(MinDesire,1,6+Rand(6));

		// Log("Desire for"@Monsters[MS[i]].MC@"at"@MinDesire@j);
		for( j=j; j>=0; --j )
			MA[MA.Length] = Monsters[MS[i]].MC;
	}
	while( MA.Length<10 ) // this wont cut any good wave (lower the ramp)...
	{
		for( i=(MS.Length-1); i>=0; --i )
		{
			if( MS[i]==iGiga )
				continue;
			MinDesire = GetMonsterDesire(Monsters[MS[i]].Difficulty,Monsters[MS[i]].EndDifficulty)*25.f;
			j = Clamp(MinDesire,1,8+Rand(6));
			for( j=j; j>=0; --j )
				MA[MA.Length] = Monsters[MS[i]].MC;
		}
	}
	
	// Finally generate random squads
	NumPerSquad = FClamp(CurDifficultyLevel*10,MinSquadSize,MaxSquadSize);
	NextInitSquads.Length = Clamp(MA.Length/NumPerSquad,1,MaxSquadsPerWave);
	NumPerSquad = float(MA.Length) / float(NextInitSquads.Length);
	// Log("Wave"@WaveNum@CurDifficultyLevel@"has"@MA.Length@"monsters"@NextInitSquads.Length@"squads");
	for( i=0; i<NextInitSquads.Length; ++i )
	{
		// Log("Squad"@i);
		MinDesire = NumPerSquad*(0.8+FRand()*0.4);
		NextInitSquads[i].MSquad.Length = Clamp(MinDesire,1,MaxZedsPerSquad);
		for( j=0; j<NextInitSquads[i].MSquad.Length; ++j )
		{
			z = Rand(MA.Length);
			// Log("Monster"@MA[z]@z);
			NextInitSquads[i].MSquad[j] = MA[z];
			MA.Remove(z,1);
			if( GigaMonsterClass!=NextInitSquads[i].MSquad[j] )
				SurvivalHUDRep.AddMonster(NextInitSquads[i].MSquad[j]);
			else bGigaFound = true;

			if( MA.Length==0 ) // Ran out of monster types.
			{
				// Log("Ran out of monsters.");
				NextInitSquads[i].MSquad.Length = j+1;
				NextInitSquads.Length = i+1;
				break;
			}
		}
	}
	if( bGigaFound )
		SurvivalHUDRep.AddMonster(GigaMonsterClass);
	SurvivalHUDRep.bDisplayInfo = true;
}
function SetupWave()
{
	local int i,UsedNumPlayers;
	local float NewMaxMonsters, DifficultyMod, NumPlayersMod;
	local string S;

	NextBossClass = None;
	DifficultyMod = float(WaveNum+1)/BossWaveInterval;
	i = int(DifficultyMod);
	bWaveBossInProgress = (i>0 && DifficultyMod==i && bHasWaveBosses);
	if( bWaveBossInProgress )
	{
		--i;
		if( i>=BossClasses.Length )
			i = Rand(BossClasses.Length);
		S = BossClasses[i];
		bSuperBossMode = (Left(S,1)=="*");
		if( bSuperBossMode )
			S = Mid(S,1);
		FullBossClass = Class<KFMonster>(DynamicLoadObject(S,Class'Class'));
		bWaveBossInProgress = (FullBossClass!=None);
		BossMessageCounter = 0;
		NumPlayersMod = FMax(NumPlayers+NumBots-1,0)*BossesPerPlayer;
		NumBossesLeft = BossCount+int(NumPlayersMod);
	}

	TraderProblemLevel = 0;
	rewardFlag=false;
	ZombiesKilled=0;
	WaveMonsters = 0;
	WaveNumClasses = 0;

    // scale number of zombies by difficulty
    if ( GameDifficulty >= 7.0 ) // Hell on Earth
    {
    	DifficultyMod=1.7;
    }
    else if ( GameDifficulty >= 5.0 ) // Suicidal
    {
    	DifficultyMod=1.5;
    }
    else if ( GameDifficulty >= 4.0 ) // Hard
    {
    	DifficultyMod=1.3;
    }
    else if ( GameDifficulty >= 2.0 ) // Normal
    {
    	DifficultyMod=1.0;
    }
    else //if ( GameDifficulty == 1.0 ) // Beginner
    {
    	DifficultyMod=0.7;
    }

    UsedNumPlayers = NumPlayers + NumBots;

    // Scale the number of zombies by the number of players. Don't want to
    // do this exactly linear, or it just gets to be too many zombies and too
    // long of waves at higher levels - Ramm
	switch ( UsedNumPlayers )
	{
		case 0:
		case 1:
			NumPlayersMod=1;
			break;
		case 2:
			NumPlayersMod=2;
			break;
		case 3:
			NumPlayersMod=2.75;
			break;
		case 4:
			NumPlayersMod=3.5;
			break;
		case 5:
			NumPlayersMod=4;
			break;
		case 6:
			NumPlayersMod=4.5;
			break;
        default:
            NumPlayersMod=UsedNumPlayers*0.8; // in case someone makes a mutator with > 6 players
	}

    NewMaxMonsters = 16.f * DifficultyMod * NumPlayersMod + (1.f+(float(WaveNum)*WaveDifficultyRamp*45.f));
    TotalMaxMonsters = Clamp(NewMaxMonsters,5,800); // 11, MAX 800, MIN 5
	NumSpecimenLeft = TotalMaxMonsters+NumMonsters;
	
	if( bHasHugeWaves )
	{
		NewMaxMonsters = ((NumPlayersMod*0.5+CurDifficultyLevel*1.5)*0.25f+1.f)*25.f;
		HugeWaveMCount = Clamp(NewMaxMonsters,25,80);
	}
	else HugeWaveMCount = 0;

	MaxMonsters = Clamp(TotalMaxMonsters,5,MaxZombiesOnce);
	//log("****** "$MaxMonsters$" Max at once!");

	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = NumSpecimenLeft+HugeWaveMCount;
	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn = true;
	AdjustedDifficulty = GameDifficulty + FMin(float(WaveNum)*WaveDifficultyRamp,3.f);

	for( i=(ZedSpawnList.Length-1); i>=0; --i )
		ZedSpawnList[i].Reset();

	SurvivalHUDRep.Cleanup();

	SquadsToUse.Length = 0;
	
	InitSquads = NextInitSquads;
	NextInitSquads.Length = 0;
}
function BuildNextSquad()
{
	local int i, RandNum;

    // Reinitialize the SquadsToUse after all the squads have been used up
	if( SquadsToUse.Length == 0 )
	{
		SquadsToUse.Length = InitSquads.Length;
		for( i=(SquadsToUse.Length-1); i>=0; --i )
			SquadsToUse[i] = i;
	}

	RandNum = Rand(SquadsToUse.Length);
	NextSpawnSquad = InitSquads[SquadsToUse[RandNum]].MSquad;

	// Take this squad out of the list so we don't get repeats
	SquadsToUse.Remove(RandNum,1);
}
function bool AddSquad()
{
	local int numspawned,OldTotalMon;
	local int ZombiesAtOnceLeft;
	local int TotalZombiesValue;

	NextForceSquadTime = Level.TimeSeconds+10.f;
	if(LastZVol==none || NextSpawnSquad.length==0)
	{
		BuildNextSquad();
		LastZVol = FindSpawningVolume();
		if( LastZVol!=None )
			LastSpawningVolume = LastZVol;
	}

	if(LastZVol == None)
	{
		NextSpawnSquad.length = 0;
		return false;
	}

    // How many zombies can we have left to spawn at once
    ZombiesAtOnceLeft = MaxMonsters;
	
	// Allow more spawn even when all of the wave is spawned.
	OldTotalMon = -1;
	if( GameStyle>=EGameStyle.GS_Continiuous && NumMonsters<MaxMonsters && TotalMaxMonsters<=0 )
	{
		OldTotalMon = TotalMaxMonsters;
		TotalMaxMonsters+=5;
	}

	// Log("Spawn on"@LastZVol.Name);
	if( LastZVol.SpawnInHere(NextSpawnSquad,,numspawned,TotalMaxMonsters,ZombiesAtOnceLeft,TotalZombiesValue) )
	{
		if( OldTotalMon>=0 )
			TotalMaxMonsters = OldTotalMon;
    	NumMonsters += numspawned;
    	WaveMonsters+= numspawned;
		HugeWaveSpawnsLeft-=numspawned;

        if( bDebugMoney )
        {
            if ( GameDifficulty >= 7.0 ) // Hell on Earth
            {
            	TotalZombiesValue *= 0.5;
            }
            else if ( GameDifficulty >= 5.0 ) // Suicidal
            {
            	TotalZombiesValue *= 0.6;
            }
            else if ( GameDifficulty >= 4.0 ) // Hard
            {
            	TotalZombiesValue *= 0.75;
            }
            else if ( GameDifficulty >= 2.0 ) // Normal
            {
            	TotalZombiesValue *= 1.0;
            }
            else // Beginner
            {
            	TotalZombiesValue *= 2.0;
            }

            TotalPossibleWaveMoney += TotalZombiesValue;
            TotalPossibleMatchMoney += TotalZombiesValue;
        }

    	NextSpawnSquad.Remove(0, numspawned);

    	return true;
    }
    else
    {
		if( OldTotalMon>=0 )
			TotalMaxMonsters = OldTotalMon;
        TryToSpawnInAnotherVolume();
        return false;
    }
}
function Killed(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType)
{
	local TeamPlayerReplicationInfo TPRI;

	if( PlayerController(Killed)!=None && SurvPRI(Killed.PlayerReplicationInfo)!=None )
		SurvPRI(Killed.PlayerReplicationInfo).DiedOnWave();

	if ( PlayerController(Killer) != none )
	{
		if ( KFMonster(KilledPawn) != None && Killed != Killer )
		{
			if ( bZEDTimeActive && KFPlayerReplicationInfo(Killer.PlayerReplicationInfo) != none &&
				 KFPlayerReplicationInfo(Killer.PlayerReplicationInfo).ClientVeteranSkill != none &&
				 KFPlayerReplicationInfo(Killer.PlayerReplicationInfo).ClientVeteranSkill.static.ZedTimeExtensions(KFPlayerReplicationInfo(Killer.PlayerReplicationInfo)) > ZedTimeExtensionsUsed )
			{
				// Force Zed Time extension for every kill as long as the Player's Perk has Extensions left
				DramaticEvent(1.0);

				ZedTimeExtensionsUsed++;
			}
			else if ( Level.TimeSeconds - LastZedTimeEvent > 0.1 )
			{
		        // Possibly do a slomo event when a zombie dies, with a higher chance if the zombie is closer to a player
		        if( Killer.Pawn != none && VSizeSquared(Killer.Pawn.Location - KilledPawn.Location) < 22500 ) // 3 meters
		            DramaticEvent(0.05);
		        else DramaticEvent(0.025);
		    }

			if ( KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements) != none )
			{
				KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddKill(KFMonster(KilledPawn).bLaserSightedEBRM14Headshotted, class<DamTypeMelee>(damageType) != none, bZEDTimeActive, class<DamTypeM4AssaultRifle>(damageType) != none || class<DamTypeM4203AssaultRifle>(damageType) != none, class<DamTypeBenelli>(damageType) != none, class<DamTypeMagnum44Pistol>(damageType) != none, class<DamTypeMK23Pistol>(damageType) != none, class<DamTypeFNFALAssaultRifle>(damageType) != none, class<DamTypeBullpup>(damageType) != none, "");

				if ( Killer.Pawn != none && KFWeapon(Killer.Pawn.Weapon) != none && KFWeapon(Killer.Pawn.Weapon).Tier3WeaponGiver != none &&
					 KFSteamStatsAndAchievements(KFWeapon(Killer.Pawn.Weapon).Tier3WeaponGiver.SteamStatsAndAchievements) != none )
				{
					KFSteamStatsAndAchievements(KFWeapon(Killer.Pawn.Weapon).Tier3WeaponGiver.SteamStatsAndAchievements).AddDroppedTier3Weapon();
					KFWeapon(Killer.Pawn.Weapon).Tier3WeaponGiver = none;
				}

				if ( Level.NetMode != NM_StandAlone && Level.Game.NumPlayers > 1 && KilledPawn.AnimAction == 'ZombieFeed' )
				{
					KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddFeedingKill();
				}

				if ( KilledPawn.IsA('ZombieClot') )
				{
					KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddClotKill();
				}
				else if ( KilledPawn.IsA('ZombieCrawler') )
				{
					KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddXMasCrawlerKill();

					if ( KilledPawn.Physics == PHYS_Falling && class<DamTypeM79Grenade>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddCrawlerKilledInMidair();
					}
					else if ( class<DamTypeCrossbow>(damageType) != none || class<DamTypeCrossbowHeadShot>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).KilledCrawlerWithCrossbow();
					}
				}
				else if ( KilledPawn.IsA('ZombieGorefast') )
				{
					if ( KFMonster(KilledPawn).bBackstabbed )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddGorefastBackstab();
					}
				}
				else if ( KilledPawn.IsA('ZombieBloat') )
				{
					KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddBloatKill(class<DamTypeBullpup>(damageType) != none);
				}
				else if ( KilledPawn.IsA('ZombieSiren') )
				{
					KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddSirenKill(class<DamTypeLawRocketImpact>(damageType) != none);
				}
				else if ( KilledPawn.IsA('ZombieStalker') )
				{
					KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddXMasStalkerKill();

					if ( class<DamTypeFrag>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddStalkerKillWithExplosives();
					}
					else if ( class<DamTypeMelee>(damageType) != none )
					{
						// 25% chance saying something about killing Stalker("Kissy, kissy, darlin!" or "Give us a kiss!")
						if ( !bDidKillStalkerMeleeMessage && FRand() < 0.25 )
						{
							PlayerController(Killer).Speech('AUTO', 19, "");
							bDidKillStalkerMeleeMessage = true;
						}
					}
					else if ( class<DamTypeWinchester>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddStalkerKillWithLAR();
					}
				}
				else if ( KilledPawn.IsA('ZombieHusk') )
				{
					if ( class<DamTypeBurned>(damageType) != none || class<DamTypeFlamethrower>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).KilledHusk(KFMonster(KilledPawn).bDamagedAPlayer);
					}
					else if ( class<DamTypeDualies>(damageType) != none || class<DamTypeDeagle>(damageType) != none || class<DamTypeDualDeagle>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).KilledHuskWithPistol();
					}
					else if ( class<DamTypeHuskGun>(damageType) != none || class<DamTypeHuskGunProjectileImpact>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).KilledXMasHuskWithHuskCannon();
					}
				}
				else if ( KilledPawn.IsA('ZombieScrake') )
				{
					if ( class<DamTypeChainsaw>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddChainsawScrakeKill();
					}
					else if ( class<DamTypeBurned>(damageType) != none || class<DamTypeFlamethrower>(damageType) != none ||
							  class<DamTypeMac10MPInc>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).ScrakeKilledByFire();
					}
					else if ( class<DamTypeM203Grenade>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddM203NadeScrakeKill();
					}
					else if ( class<DamTypeClaymoreSword>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddXMasClaymoreScrakeKill();
					}
				}
				else if ( KilledPawn.IsA('ZombieFleshPound') )
				{
					KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).KilledFleshpound(class<DamTypeMelee>(damageType) != none, class<DamTypeAA12Shotgun>(damageType) != none, class<DamTypeKnife>(damageType) != none, class<DamTypeClaymoreSword>(damageType) != none);
				}

				if ( class<KFWeaponDamageType>(damageType) != none )
				{
					class<KFWeaponDamageType>(damageType).Static.AwardKill(KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements),KFPlayerController(Killer),KFMonster(KilledPawn));

					if ( class<DamTypePipeBomb>(damageType) != none )
					{
						if ( KFPlayerReplicationInfo(Killer.PlayerReplicationInfo) != none && KFPlayerReplicationInfo(Killer.PlayerReplicationInfo).ClientVeteranSkill == class'KFVetDemolitions' )
						{
							KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddDemolitionsPipebombKill();
						}
					}
					else if ( class<DamTypeBurned>(damageType) != none )
					{
						// 1% chance of the Killer saying something about burning the enemy to death
						if ( FRand() < 0.01 && Level.TimeSeconds - LastBurnedEnemyMessageTime > BurnedEnemyMessageDelay )
						{
							PlayerController(Killer).Speech('AUTO', 20, "");
							LastBurnedEnemyMessageTime = Level.TimeSeconds;
						}
					}
					else if ( class<DamTypeSCARMK17AssaultRifle>(damageType) != none )
					{
						KFSteamStatsAndAchievements(PlayerController(Killer).SteamStatsAndAchievements).AddSCARKill();
					}
				}
			}
		}
    }

	if ( bWaveInProgress && ((MonsterController(Killed) != None) || (Monster(KilledPawn) != None)) )
	{
		++ZombiesKilled;
		NumSpecimenLeft = Max(NumSpecimenLeft-1,0);
		--NumMonsters;
		if( GameStyle>=EGameStyle.GS_Continiuous )
			KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = Max(NumSpecimenLeft + HugeWaveMCount,0);
		else KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = Max(TotalMaxMonsters + HugeWaveMCount + NumMonsters,0);
   		if ( !bDidTraderMovingMessage )
   		{
   			if ( float(ZombiesKilled) / float(ZombiesKilled + TotalMaxMonsters + HugeWaveMCount + NumMonsters - 1) >= 0.20 )
   			{
				SendTraderLine(0);
	   			bDidTraderMovingMessage = true;
	   		}
   		}
   		else if ( !bDidMoveTowardTraderMessage )
   		{
   			if ( float(ZombiesKilled) / float(ZombiesKilled + HugeWaveMCount + TotalMaxMonsters + NumMonsters - 1) >= 0.80 )
   			{
				// Have Trader tell players that the Shop's Almost Open
				SendTraderLine(1);

   				bDidMoveTowardTraderMessage = true;
   			}
   		}
		if ( (Killer != None) && Killer.bIsPlayer )
		{
			TPRI = TeamPlayerReplicationInfo(Killer.PlayerReplicationInfo);
			if ( TPRI != None )
				TPRI.AddWeaponKill(DamageType);
		}
		LastKilledMonsterClass = class<Monster>(KilledPawn.class);
	}

	Super(xTeamGame).Killed(Killer,Killed,KilledPawn,DamageType);
}

function float RatePlayerStart(NavigationPoint N, byte Team, Controller Player)
{
    local ShopVolume S;
	local int i;

	if ( GameStyle==EGameStyle.GS_Continiuous && (Team==0 || (Player!=None && Player.bIsPlayer)) )
	{
		S = KFGameReplicationInfo(GameReplicationInfo).CurrentShop;
		if( S!=None )
		{
			if( !S.bTelsInit )
				S.InitTeleports();
			for( i=(S.TelList.Length-1); i>=0; --i )
				if( S.TelList[i]==N )
					return 5000000.f+(FRand()*1000.f);
		}
		return Super(xTeamGame).RatePlayerStart(N,Team,Player)/5000.f;
	}
	return Super(Invasion).RatePlayerStart(N,Team,Player);
}

final function SendTraderLine( byte Num )
{
	local Controller C;

	For( C=Level.ControllerList; C!=None; C=C.NextController )
	{
		if( C.bIsPlayer && KFPlayerController(C)!=None )
			KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'Trader', Num);
	}
}

State MatchInProgress
{
	function float CalcNextSquadSpawnTime()
	{
		local float NextSpawnTime,SineMod;

		SineMod = 1.0 - Abs(sin(WaveTimeElapsed * SineWaveFreq));
		NextSpawnTime = KFLRules.WaveSpawnPeriod;

		// Make the zeds come faster in the earlier waves
		if( WaveNum < 7 )
		{
			if( NumPlayers == 4 )
				NextSpawnTime *= 0.85;
			else if( NumPlayers == 5 )
				NextSpawnTime *= 0.65;
			else if( NumPlayers >= 6 )
				NextSpawnTime *= 0.3;
		}
		// Give a slightly bigger breather in the later waves
		else if( WaveNum >= 7 )
		{
			if( NumPlayers <= 3 )
				NextSpawnTime *= 1.1;
			else if( NumPlayers == 4 )
				NextSpawnTime *= 1.0;
			else if( NumPlayers == 5 )
				NextSpawnTime *= 0.75;
			else if( NumPlayers >= 6 )
				NextSpawnTime *= 0.60;
		}

		NextSpawnTime += (SineMod * NextSpawnTime * 1.5);
		// Log(NextSpawnTime);
		return NextSpawnTime;
	}
	function Tick( float Delta )
	{
		Global.Tick(Delta);
		if( bSpawningMobs && (TotalMaxMonsters>0 || GameStyle>=EGameStyle.GS_Continiuous) && Level.TimeSeconds>NextMonsterTime && ((NumMonsters <= MaxMonsters) || GameStyle>=EGameStyle.GS_Continiuous || NextForceSquadTime<Level.TimeSeconds) )
		{
			if( !UpdateMonsterCount() )
			{
				EndGame(None,"TimeLimit");
				Return;
			}
			if( GameStyle>=EGameStyle.GS_Continiuous && !bWaveInProgress )
				TotalMaxMonsters = 4;

			if( bWaveBossInProgress && NextBossClass==None && NumBossesLeft>0 )
			{
				--NumBossesLeft;
				NextBossClass = FullBossClass;
				NextSpawnSquad.Length = 1;
				NextSpawnSquad[0] = NextBossClass;
			}
			AddSquad();

			if( nextSpawnSquad.length>0 || (bHadHugeWave && HugeWaveSpawnsLeft>0) )
				NextMonsterTime = Level.TimeSeconds + 0.2;
			else if( GameStyle>=EGameStyle.GS_Continiuous && (!bWaveInProgress || NumMonsters>=MaxMonsters || NumSpecimenLeft<=0) )
				NextMonsterTime = Level.TimeSeconds + CalcNextSquadSpawnTime() * 6.f;
			else NextMonsterTime = Level.TimeSeconds + CalcNextSquadSpawnTime();
		}
	}
	final function bool AllInShop()
	{
		local Controller C;
		local int i;
		
		For( C=Level.ControllerList; C!=None; C=C.NextController )
		{
			if( C.bIsPlayer && KFPawn(C.Pawn)!=None )
			{
				for( i=(ShopList.Length-1); i>=0; --i )
					if( ShopList[i].bCurrentlyOpen && ShopList[i].Encompasses(C.Pawn) )
						break;
				if( i<0 )
					return false;
			}
		}
		return true;
	}
	final function StartTradingTime()
	{
		WaveCountDown = Max(TimeBetweenWaves,1);
		KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
		bSafeRoomTime = false;
	}
	final function SmallCloseShops()
	{
		local int i;
		local Controller C;

		bTradingDoorsOpen = False;
		for( i=0; i<ShopList.Length; i++ )
		{
			if( ShopList[i].bCurrentlyOpen )
				ShopList[i].CloseShop();
		}

		// Tell all players to stop showing the path to the trader
		for ( C = Level.ControllerList; C != none; C = C.NextController )
		{
			if ( KFPlayerController(C)!=none && C.Pawn!=none && C.Pawn.Health > 0 )
			{
				KFPlayerController(C).SetShowPathToTrader(false);
				KFPlayerController(C).ClientForceCollectGarbage();
			}
		}
	}
	function Timer()
	{
		local Controller C;
		local bool bOneMessage;
		local Bot B;

		Global.Timer();

		if ( !bFinalStartup )
		{
			bFinalStartup = true;
			PlayStartupMessage();
		}
		if ( NeedPlayers() && AddBot() && (RemainingBots > 0) )
			RemainingBots--;
		GameReplicationInfo.ElapsedTime = ++ElapsedTime;
		if( !UpdateMonsterCount() )
		{
			EndGame(None,"TimeLimit");
			Return;
		}

		if( bUpdateViewTargs )
			UpdateViews();

		if(bWaveInProgress)
		{
			WaveTimeElapsed += 1.0;

			// Close Trader doors
			if (bTradingDoorsOpen)
			{
				CloseShops();
				TraderProblemLevel = 0;
			}
			if( TraderProblemLevel<4 )
			{
				if( BootShopPlayers() )
					TraderProblemLevel = 0;
				else TraderProblemLevel++;
			}
			if(!MusicPlaying)
				StartGameMusic(True);

			if( bWaveBossInProgress && bHadHugeWave && BossMessageCounter<4 )
			{
				if( ++BossMessageCounter==4 )
					BroadcastLocalizedMessage(class'SurvivalMessage', 8);
			}
			if( TotalMaxMonsters<=0 )
			{
				if( !bInitiatedWaveEnd )
				{
					bInitiatedWaveEnd = true;
					WaveEndTime = Level.TimeSeconds + FClamp(NumMonsters*10.f-WaveNum,16.f,60.f);
				}
				// if everyone's spawned and they're all dead
				if( NumMonsters<=0 || NumSpecimenLeft<=0 || ((GameStyle>=EGameStyle.GS_TimedWaves || (!bHadHugeWave && bHasHugeWaves)) && WaveEndTime<Level.TimeSeconds) )
				{
					if( !bHadHugeWave && bHasHugeWaves )
					{
						bHadHugeWave = true;
						TotalMaxMonsters = HugeWaveMCount;
						NumSpecimenLeft = HugeWaveMCount+NumMonsters;
						HugeWaveSpawnsLeft = HugeWaveMCount;
						HugeWaveMCount = 0;
						MaxMonsters*=3;
						BroadcastLocalizedMessage(class'SurvivalMessage', 7);
						NextMonsterTime = Level.TimeSeconds + 1.5;
					}
					else
					{
						DoWaveEnd();
					}
					bInitiatedWaveEnd = false;
				}
			}
		}
		else if( bSafeRoomTime )
		{
			// Open Trader doors
			if ( !bTradingDoorsOpen )
            	OpenShops();

			WaveCountDown--;
			KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
			
			if( WaveCountDown<=0 || AllInShop() )
				StartTradingTime();
		}
		else
		{
			// May kill off surviving monsters here.
			if( NumMonsters>0 )
			{
				for ( C = Level.ControllerList; C != None; C = C.NextController )
					if ( KFMonsterController(C)!=None && KFMonsterController(C).CanKillMeYet() )
					{
						C.Pawn.LifeSpan = 0.1;
						C.LifeSpan = 0.15;
						Break;
					}
			}

			WaveCountDown--;
			if ( !CalmMusicPlaying )
			{
				InitMapWaveCfg();
				StartGameMusic(False);
			}

			// Open Trader doors
			if ( WaveNum != InitialWave )
			{
				// In continiuous style, keep closed until 10 seconds left.
				if( GameStyle==EGameStyle.GS_Continiuous && WaveCountDown>10 )
				{
					if( bTradingDoorsOpen )
						SmallCloseShops();
				}
				else if( !bTradingDoorsOpen )
					OpenShops();
			}

			if ( KFGameReplicationInfo(GameReplicationInfo).CurrentShop == none )
				SelectShop();

			KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
			if ( WaveCountDown == 30 )
			{
				SendTraderLine(4); // Have Trader tell players that they've got 30 seconds
			}
			else if ( WaveCountDown == 10 )
			{
				SendTraderLine(5); // Have Trader tell players that they've got 10 seconds
			}
			else if ( WaveCountDown == 5 )
				KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn = false;
			else if ( (WaveCountDown > 0) && (WaveCountDown < 5) )
			{
				BroadcastLocalizedMessage(class'SurvivalMessage', 1);
			}
			else if ( WaveCountDown <= 1 )
			{
				bWaveInProgress = true;
				bSpawningMobs = true;
				KFGameReplicationInfo(GameReplicationInfo).bWaveInProgress = true;

				// Randomize the ammo pickups again
				if( WaveNum > 0 )
				{
					SetupPickups();
				}

				SetupWave();

				for ( C = Level.ControllerList; C != none; C = C.NextController )
				{
					if ( PlayerController(C) != none )
					{
						PlayerController(C).LastPlaySpeech = 0;

						if ( KFPlayerController(C) != none )
						{
							KFPlayerController(C).bHasHeardTraderWelcomeMessage = false;
						}
					}

					if ( Bot(C) != none )
					{
						B = Bot(C);
						InvasionBot(B).bDamagedMessage = false;
						B.bInitLifeMessage = false;

						if ( !bOneMessage && (FRand() < 0.65) )
						{
							bOneMessage = true;

							if ( (B.Squad.SquadLeader != None) && B.Squad.CloseToLeader(C.Pawn) )
							{
								B.SendMessage(B.Squad.SquadLeader.PlayerReplicationInfo, 'OTHER', B.GetMessageIndex('INPOSITION'), 20, 'TEAM');
								B.bInitLifeMessage = false;
							}
						}
					}
				}
		    }
		}
	}
	function DoWaveEnd()
	{
		local Controller C;
		local KFDoorMover KFDM;
		local PlayerController Survivor;
		local int SurvivorCount;

        // Only reset this at the end of wave 0. That way the sine wave that scales
        // the intensity up/down will be somewhat random per wave
        if( WaveNum < 1 )
            WaveTimeElapsed = 0;

		if ( !rewardFlag )
			RewardSurvivingPlayers();

		if( bDebugMoney )
		{
			log("$$$$$$$$$$$$$$$$ Wave "$WaveNum$" TotalPossibleWaveMoney = "$TotalPossibleWaveMoney,'Debug');
			log("$$$$$$$$$$$$$$$$ TotalPossibleMatchMoney = "$TotalPossibleMatchMoney,'Debug');
			TotalPossibleWaveMoney=0;
		}

		// Clear Trader Message status
		bDidTraderMovingMessage = false;
		bDidMoveTowardTraderMessage = false;

		bSafeRoomTime = (GameStyle==EGameStyle.GS_Continiuous);
		bSpawningMobs = (GameStyle>=EGameStyle.GS_Continiuous);
		bWaveInProgress = false;
		bWaveBossInProgress = false;
		bNotifiedLastManStanding = false;
		KFGameReplicationInfo(GameReplicationInfo).bWaveInProgress = false;

		WaveCountDown = Max(TimeBetweenWaves,1);
		KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
		InvasionGameReplicationInfo(GameReplicationInfo).FinalWave = Max(InvasionGameReplicationInfo(GameReplicationInfo).FinalWave,++WaveNum);
		InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;
		if( SurvivalStats!=None )
			SurvivalStats.SetCurrentWave(WaveNum);

		for ( C = Level.ControllerList; C != none; C = C.NextController )
		{
			if ( C.PlayerReplicationInfo != none )
			{
				C.PlayerReplicationInfo.bOutOfLives = false;
				C.PlayerReplicationInfo.NumLives = 0;
				C.StartSpot = None;

				if ( KFPlayerController(C) != none )
				{
					if ( KFPlayerReplicationInfo(C.PlayerReplicationInfo) != none )
					{
						KFPlayerController(C).bChangedVeterancyThisWave = false;

						if ( KFPlayerReplicationInfo(C.PlayerReplicationInfo).ClientVeteranSkill != KFPlayerController(C).SelectedVeterancy )
						{
							KFPlayerController(C).SendSelectedVeterancyToServer();
						}
					}
				}

				if ( C.Pawn != none )
				{
					if ( PlayerController(C) != none )
					{
						Survivor = PlayerController(C);
						SurvivorCount++;

						if( SurvPRI(C.PlayerReplicationInfo)!=None )
							SurvPRI(C.PlayerReplicationInfo).SurvivedWave();
					}
				}
				else if ( !C.PlayerReplicationInfo.bOnlySpectator )
				{
					C.PlayerReplicationInfo.Score = Max(MinRespawnCash,int(C.PlayerReplicationInfo.Score));

					if( PlayerController(C) != none )
					{
						PlayerController(C).GotoState('PlayerWaiting');
						PlayerController(C).SetViewTarget(C);
						PlayerController(C).ClientSetBehindView(false);
						PlayerController(C).bBehindView = False;
						PlayerController(C).ClientSetViewTarget(C.Pawn);
					}

					C.ServerReStartPlayer();
				}

				if ( KFPlayerController(C) != none )
				{
					if ( KFSteamStatsAndAchievements(PlayerController(C).SteamStatsAndAchievements) != none )
						KFSteamStatsAndAchievements(PlayerController(C).SteamStatsAndAchievements).WaveEnded();

					KFPlayerController(C).bSpawnedThisWave = false;
				}
			}
		}
		BroadcastLocalizedMessage(class'WaitingMessage', 2);

		if ( Level.NetMode != NM_StandAlone && Level.Game.NumPlayers > 1 &&
			 SurvivorCount == 1 && Survivor != none && KFSteamStatsAndAchievements(Survivor.SteamStatsAndAchievements) != none )
		{
			KFSteamStatsAndAchievements(Survivor.SteamStatsAndAchievements).AddOnlySurvivorOfWave();
		}

		bUpdateViewTargs = True;

		// respawn doors
		foreach DynamicActors(class'KFDoorMover', KFDM)
			KFDM.RespawnDoor();
			
		CurDifficultyLevel+=WaveDifficultyRamp;
		bHadHugeWave = false;
		HugeWaveMCount = 0;
		InitNextWave();
		
		if( SurvivalStats!=None && ++WavesCounter>=StatsSaveWaves )
		{
			WavesCounter = 0;
			SaveAllStats();
		}
	}
	function OpenShops()
	{
		local int i;
		local Controller C;

		bTradingDoorsOpen = True;

		for( i=0; i<ShopList.Length; i++ )
		{
			if( ShopList[i].bAlwaysClosed )
				continue;
			if( ShopList[i].bAlwaysEnabled )
				ShopList[i].OpenShop();
		}

        if ( KFGameReplicationInfo(GameReplicationInfo).CurrentShop == none )
            SelectShop();

		KFGameReplicationInfo(GameReplicationInfo).CurrentShop.OpenShop();
		SendTraderLine(2); // Have Trader tell players that the Shop's Open

		// Tell all players to start showing the path to the trader
		For( C=Level.ControllerList; C!=None; C=C.NextController )
		{
			if( C.Pawn!=None && C.Pawn.Health>0 )
			{
				if( KFPlayerController(C) !=None )
				{
					KFPlayerController(C).SetShowPathToTrader(true);

					// Hints
					KFPlayerController(C).CheckForHint(31);
					HintTime_1 = Level.TimeSeconds + 11;
				}
			}
		}
	}
}

defaultproperties
{
     GameStyle=1
     Monsters(0)=(MonsterClass="KFChar.ZombieClot_STANDARD",EndDifficulty=1.000000,Count=10.000000)
     Monsters(1)=(MonsterClass="KFChar.ZombieBloat_STANDARD",Difficulty=0.250000,EndDifficulty=1.500000,Count=6.000000)
     Monsters(2)=(MonsterClass="GigaBloat",Difficulty=0.600000,EndDifficulty=1.500000,Count=2.000000,bSuperMonster=True)
     Monsters(3)=(MonsterClass="KFChar.ZombieStalker_STANDARD",Difficulty=0.200000,EndDifficulty=0.900000,Count=9.000000)
     Monsters(4)=(MonsterClass="KFChar.ZombieCrawler_STANDARD",Difficulty=0.150000,EndDifficulty=0.900000,Count=8.000000)
     Monsters(5)=(MonsterClass="KFChar.ZombieGorefast_STANDARD",Difficulty=0.270000,EndDifficulty=2.000000,Count=6.000000)
     Monsters(6)=(MonsterClass="KFChar.ZombieHusk_STANDARD",Difficulty=0.400000,EndDifficulty=20.000000,Count=5.000000)
     Monsters(7)=(MonsterClass="GigaHusk",Difficulty=1.000000,EndDifficulty=40.000000,Count=2.000000,bSuperMonster=True)
     Monsters(8)=(MonsterClass="KFChar.ZombieSiren_STANDARD",Difficulty=0.500000,EndDifficulty=20.000000,Count=6.000000)
     Monsters(9)=(MonsterClass="GigaSiren",Difficulty=1.300000,EndDifficulty=50.000000,Count=3.000000,bSuperMonster=True)
     Monsters(10)=(MonsterClass="KFChar.ZombieShade",Difficulty=1.100000,EndDifficulty=10.000000,Count=5.000000)
     Monsters(11)=(MonsterClass="KFChar.ZombieScrake_STANDARD",Difficulty=0.600000,EndDifficulty=40.000000,Count=5.000000)
     Monsters(12)=(MonsterClass="GigaScrake",Difficulty=1.600000,EndDifficulty=100.000000,Count=2.000000,bSuperMonster=True)
     Monsters(13)=(MonsterClass="KFChar.ZombieFleshpound_STANDARD",Difficulty=0.700000,EndDifficulty=100.000000,Count=6.000000)
     Monsters(14)=(MonsterClass="GigaFleshPound",Difficulty=2.000000,EndDifficulty=1000.000000,Count=3.000000,bSuperMonster=True)
     Monsters(15)=(MonsterClass="KFChar.ZombieFleshpoundRange",Difficulty=1.500000,EndDifficulty=100.000000,Count=5.000000)
     Monsters(16)=(MonsterClass="GigaFleshPoundRange",Difficulty=2.200000,EndDifficulty=1000.000000,Count=3.000000,bSuperMonster=True)
     Monsters(17)=(MonsterClass="ZombiePat",Difficulty=2.000000,EndDifficulty=1000.000000,Count=4.000000)
     WaveDifficultyRamp=0.100000
     InitialDifficulty=0.150000
     BossesPerPlayer=0.350000
     BossWaveInterval=3
     MaxSquadsPerWave=20
     MaxZedsPerSquad=6
     StatsSaveWaves=4
     MinSquadSize=3
     MaxSquadSize=9
     BossCount=1
     BossClasses(0)="*KFChar.ZombieClot_STANDARD"
     BossClasses(1)="*KFChar.ZombieBloat_STANDARD"
     BossClasses(2)="*KFChar.ZombieGorefast_STANDARD"
     BossClasses(3)="*KFChar.ZombieHusk_STANDARD"
     BossClasses(4)="*KFChar.ZombieSiren_STANDARD"
     BossClasses(5)="*KFChar.ZombieScrake_STANDARD"
     BossClasses(6)="*KFChar.ZombieFleshpound_STANDARD"
     BossClasses(7)="*KFChar.ZombieFleshpoundRange"
     bHasHugeWaves=True
     bHasWaveBosses=True
     bTrackStats=True
     GameName="Some Lazy Gametype"
}
