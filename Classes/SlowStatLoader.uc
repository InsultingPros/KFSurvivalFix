Class SlowStatLoader extends Info;

var SurvGameStats S;
var int i,j,x,Count,IR;

auto state InitStats
{
Begin:
	Sleep(0.05f);
	
	S.TopScores.Length = S.PL.Length; // Alloc memory blocks first.

	for( i=(S.PL.Length-1); i>=0; --i )
	{
		S.TopScores[i] = i;
		
		if( ++Count>=40000 )
		{
			Count = 0;
			Sleep(0.01f); // Pause loop for next frame.
		}
	}
	
	// Sort ranking.
	// Note: Expensive UnrealScript loop, if only there were a native way of sorting arrays.
	for( i=(S.TopScores.Length-1); i>=1; --i )
	{
		for( j=(i-1); j>=0; --j )
		{
			if( S.PL[S.TopScores[i]].S>S.PL[S.TopScores[j]].S )
			{
				// Swap em.
				x = S.TopScores[i];
				S.TopScores[i] = S.TopScores[j];
				S.TopScores[j] = x;
				
				if( ++Count>=40000 )
				{
					Count = 0;
					Sleep(0.01f); // Pause loop for next frame.
				}
			}
		}
	}

	// Log("Player["$TopScores[0]$"]:"$PL[TopScores[0]].I@PL[TopScores[0]].N$"="$0);
	S.PL[S.TopScores[0]].Rank = 0;
	j = S.TopScores.Length;
	for( i=1; i<j; ++i )
	{
		if( S.PL[S.TopScores[i]].S!=S.PL[S.TopScores[i-1]].S )
			IR = i;

		// Log("Player["$TopScores[i]$"]:"$PL[TopScores[i]].I@PL[TopScores[i]].N$"="$IR);
		S.PL[S.TopScores[i]].Rank = IR;
		
		if( ++Count>=40000 )
		{
			Count = 0;
			Sleep(0.01f); // Pause loop for next frame.
		}
	}

	S.bRanksInit = True;
	KFSurvival(Level.Game).StatsCompleted(); // Allow game to init all logged in clients now.
	Destroy();
}

defaultproperties
{
}
