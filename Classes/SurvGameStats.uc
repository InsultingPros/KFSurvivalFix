Class SurvGameStats extends Object
	Config(KFSurvivalStats)
	PerObjectConfig;

struct FPlayerEntry
{
	var() config string I,N;
	var() config int S;
	var transient int Rank;
};
var() config array<FPlayerEntry> PL;
var() config int MaxPlayerEntires;
var array<int> TopScores;
var LevelStats Stats;
var bool bDirty,bRanksInit;

final function string GetSafeName( string S )
{
	ReplaceText(S,"\"","'");
	ReplaceText(S,"\\","|");
	ReplaceText(S,"/","|");
	ReplaceText(S,Chr(10),"");
	ReplaceText(S,Chr(13),"");
	return S;
}
final function InitStats( name LevelName )
{
	Stats = new(None,string(LevelName)) Class'LevelStats';
}
final function int GetPlayerLevel( string InID, string InName, out int PlayerIndex, out int iRank )
{
	local int b,i;

	PlayerIndex = -1;
	if( !bRanksInit )
	{
		iRank = -1;
		return -1;
	}

	if( Stats.ST.Length==0 )
		return -1;

	PlayerIndex = GetPlayerIndex(InID);
	if( PlayerIndex==-1 )
		return -1;

	iRank = PL[PlayerIndex].Rank;
	b = Stats.ST.Length;
	InName = GetSafeName(InName);

	for( i=0; i<b; ++i )
		if( Stats.ST[i].P==PlayerIndex )
		{
			bDirty = (bDirty || PL[PlayerIndex].N!=InName);
			if( bDirty )
				PL[PlayerIndex].N = InName; // Update name (if changed).
			return Stats.ST[i].C; // found
		}
	return -1;
}
final function int GetPlayerIndex( string InID, optional bool bAddNew )
{
	local int i;

	InID = Caps(InID);
	for( i=0; i<PL.Length; ++i )
	{
		if( PL[i].I==InID )  // check for a match
			return i; // found
	}
	if( !bAddNew || PL.Length>MaxPlayerEntires )
		return -1;

	// add at end
	PL.Length = i+1;
	PL[i].I = InID;
	PL[i].Rank = -1;
	bDirty = true;
	return i;
}
final function SetPlayerLevel( string InID, string InName, int NewWave, int UsedIndex )
{
	local int i;

	InName = GetSafeName(InName);
	if( UsedIndex==-1 )
	{
		UsedIndex = GetPlayerIndex(InID,true);
		if( UsedIndex==-1 )
			return;
	}
	if( PL[UsedIndex].N!=InName )
	{
		PL[UsedIndex].N = InName;
		bDirty = true;
	}
	PL[UsedIndex].S+=NewWave;

	// search list for player
	for( i=0; i<Stats.ST.Length; i++ )
	{
		if( Stats.ST[i].P==UsedIndex )  // found player
		{
			if( Stats.ST[i].C<NewWave )
			{
				bDirty = true;
				PL[UsedIndex].S-=Stats.ST[i].C; // Substract with old score.
				Stats.ST[i].C = NewWave;
			}
			else PL[UsedIndex].S-=NewWave; // Restore score as new score isn't a record.
			return;
		}
	}

	Stats.ST.Length = i+1;
	Stats.ST[i].P = UsedIndex;
	Stats.ST[i].C = NewWave;
	bDirty = true;
}
final function int GetBestWaveNum()
{
	return Stats.Best;
}
final function SetCurrentWave( int WaveNum )
{
	if( Stats.Best<WaveNum )
	{
		Stats.Best = WaveNum;
		bDirty = true;
	}
}
final function SaveStats()
{
	if( bDirty )
	{
		bDirty = false;
		SaveConfig();
		Stats.SaveConfig();
	}
}

defaultproperties
{
     MaxPlayerEntires=2000
}
