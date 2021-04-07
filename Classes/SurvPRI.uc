// Custom KF Player Rep info. Now including experience levels.
class SurvPRI extends KFPlayerReplicationInfo
	DependsOn(KFSurvival);

var byte SurvivedWaves,BestSurvivedWaves;
var int PlayerIndex,PlayerRank,SendIndex;
var string ClientIDHash;
var array<KFSurvival.FTopPlayerEntry> TopPlayers;
var bool bIsNetReady;

replication
{
	// Things the server should send to the client.
	reliable if( Role==Role_Authority )
		SurvivedWaves,BestSurvivedWaves,PlayerRank,ClientGetTop;

	unreliable if( Role==Role_Authority )
		CheckClientNetReady;
	unreliable if( Role<ROLE_Authority )
		ServerNetReady;
}

function SurvivedWave()
{
	BestSurvivedWaves = Max(BestSurvivedWaves,++SurvivedWaves);
}
function DiedOnWave()
{
	SurvivedWaves = 0;
}
simulated final function ClientGetTop( KFSurvival.FTopPlayerEntry E )
{
	local int i;
	
	// Log("ClientGetTop"@E.Player@E.Score);
	// Make sure packet wasn't received out of order.
	for( i=0; i<TopPlayers.Length; ++i )
		if( TopPlayers[i].Score<E.Score )
		{
			TopPlayers.Insert(i,1);
			TopPlayers[i] = E;
			return;
		}
	TopPlayers.Length = i+1;
	TopPlayers[i] = E;
}
simulated final function CheckClientNetReady()
{
	ServerNetReady();
}
final function ServerNetReady()
{
	bIsNetReady = true;
}

Auto state GetScores
{
Begin:
	Sleep(0.5f);
	if( xPlayer(Owner)!=None && KFSurvival(Level.Game)!=None && KFSurvival(Level.Game).SurvivalStats!=None )
	{
		Sleep(3.f);
		while( !KFSurvival(Level.Game).bGotTopPlayers )
			Sleep(0.1f);

		if( NetConnection(xPlayer(Owner).Player)!=None )
		{
			while( !bIsNetReady )
			{
				CheckClientNetReady();
				Sleep(1.f);
			}
			for( SendIndex=0; SendIndex<KFSurvival(Level.Game).TopPlayers.Length; ++SendIndex )
			{
				ClientGetTop(KFSurvival(Level.Game).TopPlayers[SendIndex]);
				Sleep(0.1f);
			}
		}
		else
		{
			TopPlayers = KFSurvival(Level.Game).TopPlayers;
		}
	}
	GoToState('');
}

defaultproperties
{
     PlayerRank=-1
}
